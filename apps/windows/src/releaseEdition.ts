export type ReleaseEdition = "development" | "steam_full" | "steam_demo" | "web_teaser";

export function releaseEditionFromEnvironment(
  development: boolean,
  configured?: string,
): ReleaseEdition {
  if (development) return "development";
  if (configured === "steam_full" || configured === "web_teaser") return configured;
  return "steam_demo";
}

export function includesProCareer(edition: ReleaseEdition): boolean {
  return edition === "development" || edition === "steam_full";
}
