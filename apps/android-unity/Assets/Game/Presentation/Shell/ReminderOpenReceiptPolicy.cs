namespace Baseball.Presentation.Shell
{
    public enum ReminderOpenReceiptAction
    {
        Wait,
        PersistAnalytics,
        PresentNavigation,
        CompleteHandled,
    }

    /// <summary>
    /// Pure save-before-side-effect contract for notification opens. The analytics receipt and the
    /// navigation-completed receipt are deliberately separate: a crash after analytics persistence
    /// can restore the destination without sending the SDK event twice.
    /// </summary>
    public static class ReminderOpenReceiptPolicy
    {
        public const string NavigationReceiptEventId = "reminder_navigation_completed";

        public static ReminderOpenReceiptAction BeforeDispatch(
            bool storeReady,
            bool storeBusy,
            bool analyticsReceiptExists,
            bool navigationReceiptExists)
        {
            if (!storeReady || storeBusy) return ReminderOpenReceiptAction.Wait;
            if (navigationReceiptExists) return ReminderOpenReceiptAction.CompleteHandled;
            return analyticsReceiptExists
                ? ReminderOpenReceiptAction.PresentNavigation
                : ReminderOpenReceiptAction.PersistAnalytics;
        }

        public static ReminderOpenReceiptAction AfterAnalyticsDispatch(
            bool emittedAfterAppliedReceipt,
            bool analyticsReceiptExists,
            bool navigationReceiptExists)
        {
            if (navigationReceiptExists) return ReminderOpenReceiptAction.CompleteHandled;
            return emittedAfterAppliedReceipt || analyticsReceiptExists
                ? ReminderOpenReceiptAction.PresentNavigation
                : ReminderOpenReceiptAction.Wait;
        }

        public static bool CanCompletePlatformRequest(bool navigationReceiptExists) =>
            navigationReceiptExists;
    }
}
