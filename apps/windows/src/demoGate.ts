export function hasCompletedSteamDemo(demoMode: boolean, importantGamesCompleted: number) {
  return demoMode && importantGamesCompleted >= 1;
}
