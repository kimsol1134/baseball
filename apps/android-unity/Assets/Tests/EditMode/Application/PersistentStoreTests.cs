using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.Stores;
using NUnit.Framework;

namespace Baseball.Application.Tests
{
    public sealed class PersistentStoreTests
    {
        [Test]
        public async Task Dispatch_SavesBeforePublishing()
        {
            var initial = TestSnapshot.Initial;
            var saver = new BlockingSaver();
            using (var store = new PersistentStore<TestSnapshot, int>(
                       initial,
                       new IncrementTransition(),
                       saver))
            {
                var published = false;
                store.StatePublished += _ => published = true;

                var dispatch = store.DispatchAsync(new CommandEnvelope<int>("cmd-1", 0, 5));
                await saver.Started.Task;

                Assert.That(store.Current, Is.SameAs(initial));
                Assert.That(published, Is.False);
                Assert.That(store.IsBusy, Is.True);

                saver.Release.TrySetResult(true);
                var result = await dispatch;

                Assert.That(result.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That(store.Current.Value, Is.EqualTo(5));
                Assert.That(store.Current.Revision, Is.EqualTo(1));
                Assert.That(published, Is.True);
                Assert.That(store.IsBusy, Is.False);
            }
        }

        [Test]
        public async Task Dispatch_WhenSaveFails_DoesNotPublishCandidate()
        {
            var initial = TestSnapshot.Initial;
            using (var store = new PersistentStore<TestSnapshot, int>(
                       initial,
                       new IncrementTransition(),
                       new ThrowingSaver()))
            {
                var publishCount = 0;
                store.StatePublished += _ => publishCount++;

                var result = await store.DispatchAsync(
                    new CommandEnvelope<int>("cmd-1", 0, 9));

                Assert.That(result.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current, Is.SameAs(initial));
                Assert.That(publishCount, Is.Zero);
            }
        }

        [Test]
        public async Task Dispatch_DoubleSubmit_AppliesAndSavesOnlyOnce()
        {
            var transition = new IncrementTransition();
            var saver = new RecordingSaver();
            using (var store = new PersistentStore<TestSnapshot, int>(
                       TestSnapshot.Initial,
                       transition,
                       saver))
            {
                var envelope = new CommandEnvelope<int>("same-command", 0, 3);
                var results = await Task.WhenAll(
                    store.DispatchAsync(envelope),
                    store.DispatchAsync(envelope));

                Assert.That(
                    results.Select(result => result.Status),
                    Is.EquivalentTo(new[] { DispatchStatus.Applied, DispatchStatus.AlreadyApplied }));
                Assert.That(transition.ApplyCount, Is.EqualTo(1));
                Assert.That(saver.SaveCount, Is.EqualTo(1));
                Assert.That(store.Current.Value, Is.EqualTo(3));
            }
        }

        [Test]
        public async Task Dispatch_StaleRevision_DoesNotRunReducerOrSave()
        {
            var transition = new IncrementTransition();
            var saver = new RecordingSaver();
            using (var store = new PersistentStore<TestSnapshot, int>(
                       TestSnapshot.Initial,
                       transition,
                       saver))
            {
                var result = await store.DispatchAsync(
                    new CommandEnvelope<int>("cmd-1", 42, 3));

                Assert.That(result.Status, Is.EqualTo(DispatchStatus.StaleRevision));
                Assert.That(transition.ApplyCount, Is.Zero);
                Assert.That(saver.SaveCount, Is.Zero);
            }
        }

        [TestCase(InvalidTransitionMode.SameReference)]
        [TestCase(InvalidTransitionMode.SkippedRevision)]
        [TestCase(InvalidTransitionMode.MissingReceipt)]
        public async Task Dispatch_InvalidReducerOutput_IsRejectedBeforeSave(
            InvalidTransitionMode mode)
        {
            var saver = new RecordingSaver();
            using (var store = new PersistentStore<TestSnapshot, int>(
                       TestSnapshot.Initial,
                       new InvalidTransition(mode),
                       saver))
            {
                var result = await store.DispatchAsync(
                    new CommandEnvelope<int>("cmd-1", 0, 1));

                Assert.That(result.Status, Is.EqualTo(DispatchStatus.InvalidTransition));
                Assert.That(saver.SaveCount, Is.Zero);
                Assert.That(store.Current, Is.SameAs(TestSnapshot.Initial));
            }
        }

        [Test]
        public async Task Dispatch_DomainFailure_DoesNotSave()
        {
            var saver = new RecordingSaver();
            using (var store = new PersistentStore<TestSnapshot, int>(
                       TestSnapshot.Initial,
                       new RejectingTransition(),
                       saver))
            {
                var result = await store.DispatchAsync(
                    new CommandEnvelope<int>("cmd-1", 0, 1));

                Assert.That(result.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                Assert.That(result.ErrorCode, Is.EqualTo("domain.not_allowed"));
                Assert.That(saver.SaveCount, Is.Zero);
            }
        }

        private sealed class TestSnapshot : IStoreSnapshot
        {
            public static readonly TestSnapshot Initial =
                new TestSnapshot(0, 0, Array.Empty<string>());

            public TestSnapshot(ulong revision, int value, IEnumerable<string> receipts)
            {
                Revision = revision;
                Value = value;
                Receipts = new HashSet<string>(receipts, StringComparer.Ordinal);
            }

            public ulong Revision { get; }

            public int Value { get; }

            public HashSet<string> Receipts { get; }

            public bool HasCommandReceipt(string commandId) => Receipts.Contains(commandId);
        }

        private sealed class IncrementTransition : IStateTransition<TestSnapshot, int>
        {
            public int ApplyCount { get; private set; }

            public TransitionResult<TestSnapshot> Apply(
                TestSnapshot currentState,
                int command,
                string commandId)
            {
                ApplyCount++;
                return TransitionResult<TestSnapshot>.Success(
                    new TestSnapshot(
                        currentState.Revision + 1,
                        currentState.Value + command,
                        currentState.Receipts.Concat(new[] { commandId })));
            }
        }

        private sealed class RejectingTransition : IStateTransition<TestSnapshot, int>
        {
            public TransitionResult<TestSnapshot> Apply(
                TestSnapshot currentState,
                int command,
                string commandId)
            {
                return TransitionResult<TestSnapshot>.Failure("domain.not_allowed");
            }
        }

        public enum InvalidTransitionMode
        {
            SameReference,
            SkippedRevision,
            MissingReceipt
        }

        private sealed class InvalidTransition : IStateTransition<TestSnapshot, int>
        {
            private readonly InvalidTransitionMode _mode;

            public InvalidTransition(InvalidTransitionMode mode)
            {
                _mode = mode;
            }

            public TransitionResult<TestSnapshot> Apply(
                TestSnapshot currentState,
                int command,
                string commandId)
            {
                switch (_mode)
                {
                    case InvalidTransitionMode.SameReference:
                        return TransitionResult<TestSnapshot>.Success(currentState);
                    case InvalidTransitionMode.SkippedRevision:
                        return TransitionResult<TestSnapshot>.Success(
                            new TestSnapshot(2, command, new[] { commandId }));
                    default:
                        return TransitionResult<TestSnapshot>.Success(
                            new TestSnapshot(1, command, Array.Empty<string>()));
                }
            }
        }

        private sealed class RecordingSaver : IStateSaver<TestSnapshot>
        {
            public int SaveCount { get; private set; }

            public Task SaveAsync(TestSnapshot state, CancellationToken cancellationToken)
            {
                SaveCount++;
                return Task.CompletedTask;
            }
        }

        private sealed class BlockingSaver : IStateSaver<TestSnapshot>
        {
            public TaskCompletionSource<bool> Started { get; } =
                new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

            public TaskCompletionSource<bool> Release { get; } =
                new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

            public async Task SaveAsync(TestSnapshot state, CancellationToken cancellationToken)
            {
                Started.TrySetResult(true);
                using (cancellationToken.Register(() => Release.TrySetCanceled()))
                {
                    await Release.Task;
                }
            }
        }

        private sealed class ThrowingSaver : IStateSaver<TestSnapshot>
        {
            public Task SaveAsync(TestSnapshot state, CancellationToken cancellationToken)
            {
                throw new InvalidOperationException("disk full");
            }
        }
    }
}
