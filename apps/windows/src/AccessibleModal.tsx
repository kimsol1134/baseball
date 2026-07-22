import { useEffect, useRef, type ReactNode } from "react";

const FOCUSABLE = [
  "a[href]",
  "button:not([disabled])",
  "input:not([disabled])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "[tabindex]:not([tabindex='-1'])",
].join(",");

interface AccessibleModalProps {
  children: ReactNode;
  className: string;
  labelledBy?: string;
  label?: string;
  live?: "polite" | "assertive";
  onEscape?: () => void;
}

export function AccessibleModal({ children, className, labelledBy, label, live, onEscape }: AccessibleModalProps) {
  const modalRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const modal = modalRef.current;
    if (!modal) return;
    const returnTarget = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const inertStates = new Map<HTMLElement, boolean>();
    let branch: HTMLElement = modal;
    let parent = branch.parentElement;

    while (parent) {
      Array.from(parent.children).forEach((sibling) => {
        if (sibling === branch || !(sibling instanceof HTMLElement)) return;
        inertStates.set(sibling, sibling.inert);
        sibling.inert = true;
      });
      if (parent === document.body) break;
      branch = parent;
      parent = parent.parentElement;
    }

    const focusFirst = () => {
      const first = modal.querySelector<HTMLElement>(FOCUSABLE);
      (first ?? modal).focus();
    };
    const frame = window.requestAnimationFrame(focusFirst);
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape" && onEscape) {
        event.preventDefault();
        onEscape();
        return;
      }
      if (event.key !== "Tab") return;
      const focusable = Array.from(modal.querySelectorAll<HTMLElement>(FOCUSABLE));
      if (focusable.length === 0) {
        event.preventDefault();
        modal.focus();
        return;
      }
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      window.cancelAnimationFrame(frame);
      document.removeEventListener("keydown", handleKeyDown);
      inertStates.forEach((wasInert, element) => { element.inert = wasInert; });
      returnTarget?.focus();
    };
  }, [onEscape]);

  return (
    <section ref={modalRef} className={className} role="dialog" aria-modal="true"
      aria-labelledby={labelledBy} aria-label={label} aria-live={live} tabIndex={-1}>
      {children}
    </section>
  );
}
