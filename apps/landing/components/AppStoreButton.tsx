import type { AnchorHTMLAttributes, ReactNode } from "react";

type AppStoreButtonProps = AnchorHTMLAttributes<HTMLAnchorElement> & {
  children: ReactNode;
  variant?: "primary" | "secondary" | "gold";
};

/// Apple 로고는 상표라 이미지로 재현하지 않는다. 대신 중립적인 다운로드 표식을 쓴다.
/// Apple이 배포하는 공식 "App Store에서 다운로드" 배지를 쓰려면 별도 에셋과 사용 지침을 따라야 한다.
export function AppStoreMark() {
  return (
    <span className="store-mark" aria-hidden="true">
      <svg viewBox="0 0 16 16" width="15" height="15" focusable="false">
        <path
          d="M8 1.6v9.2M8 10.8 4.7 7.5M8 10.8l3.3-3.3M2.6 13.2h10.8"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </span>
  );
}

export function AppStoreButton({
  children,
  className = "",
  variant = "primary",
  ...props
}: AppStoreButtonProps) {
  return (
    <a className={`button button-${variant} ${className}`.trim()} {...props}>
      <AppStoreMark />
      <span>{children}</span>
    </a>
  );
}
