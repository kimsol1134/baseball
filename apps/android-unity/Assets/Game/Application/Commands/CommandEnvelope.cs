using System;

namespace Baseball.Application.Commands
{
    public sealed class CommandEnvelope<TCommand>
    {
        public CommandEnvelope(string commandId, ulong expectedRevision, TCommand command)
        {
            if (string.IsNullOrWhiteSpace(commandId))
            {
                throw new ArgumentException("A command ID is required.", nameof(commandId));
            }

            CommandId = commandId;
            ExpectedRevision = expectedRevision;
            Command = command ?? throw new ArgumentNullException(nameof(command));
        }

        public string CommandId { get; }

        public ulong ExpectedRevision { get; }

        public TCommand Command { get; }
    }
}
