namespace Baseball.Presentation.Pitch
{
    /// <summary>Unity-free single-pointer ownership used by aim and release controls.</summary>
    public sealed class PitchPointerCaptureState
    {
        private int? _aimPointerId;
        private int? _releasePointerId;

        public int? AimPointerId => _aimPointerId;
        public int? ReleasePointerId => _releasePointerId;

        public bool TryBeginAim(int pointerId)
        {
            if (_aimPointerId.HasValue) return false;
            _aimPointerId = pointerId;
            return true;
        }

        public bool OwnsAim(int pointerId) => _aimPointerId == pointerId;

        public bool EndAim(int pointerId)
        {
            if (!OwnsAim(pointerId)) return false;
            _aimPointerId = null;
            return true;
        }

        public bool TryBeginRelease(int pointerId)
        {
            if (_releasePointerId.HasValue) return false;
            _releasePointerId = pointerId;
            return true;
        }

        public bool OwnsRelease(int pointerId) => _releasePointerId == pointerId;

        public bool EndRelease(int pointerId)
        {
            if (!OwnsRelease(pointerId)) return false;
            _releasePointerId = null;
            return true;
        }

        public bool CancelAim(int pointerId) => EndAim(pointerId);
        public bool CancelRelease(int pointerId) => EndRelease(pointerId);

        public bool CancelAll()
        {
            bool releaseWasActive = _releasePointerId.HasValue;
            _aimPointerId = null;
            _releasePointerId = null;
            return releaseWasActive;
        }
    }
}
