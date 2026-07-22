import type { AnchorHTMLAttributes, ReactNode } from "react";

type SteamButtonProps = AnchorHTMLAttributes<HTMLAnchorElement> & {
  children: ReactNode;
  variant?: "primary" | "secondary" | "gold";
};

export function SteamMark() {
  return (
    <span className="steam-mark" aria-hidden="true">
      <span />
    </span>
  );
}

export function SteamButton({
  children,
  className = "",
  variant = "primary",
  ...props
}: SteamButtonProps) {
  return (
    <a className={`button button-${variant} ${className}`.trim()} {...props}>
      <SteamMark />
      <span>{children}</span>
    </a>
  );
}
