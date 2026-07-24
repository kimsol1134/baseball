import { AvatarFace, type AvatarRole } from "./AvatarFace";

interface Props {
  label?: string;
  title: string;
  record?: string;
  description?: string;
  className?: string;
  imageSrc?: string;
  imageAlt?: string;
  avatarRole?: AvatarRole;
}

function inferRole(label: string | undefined, title: string): AvatarRole {
  const haystack = `${label ?? ""} ${title}`;
  if (haystack.includes("감독") || haystack.includes("코치")) return "coach";
  if (haystack.includes("포수")) return "catcher";
  if (haystack.includes("라이벌") || haystack.includes("경쟁자") || haystack.includes("사냥") || haystack.includes("타자")) return "rival";
  return "player";
}

export function CharacterProfile({ label, title, record, description, className, imageSrc, imageAlt, avatarRole }: Props) {
  const classes = ["character-profile", "has-portrait", className].filter(Boolean).join(" ");
  const visibleRecord = record?.trim();
  const visibleDescription = description?.trim();
  const role = avatarRole ?? inferRole(label, title);

  return <div className={classes}>
    {imageSrc
      ? <img className="character-profile__portrait" src={imageSrc} alt={imageAlt ?? ""} width="58" height="76" loading="lazy" decoding="async" />
      : <AvatarFace className="character-profile__portrait" seed={title} role={role} width={58} height={76} />}
    {label ? <span>{label}</span> : null}
    <strong>{title}</strong>
    {visibleRecord ? <small>{visibleRecord}</small> : null}
    {visibleDescription ? <p>{visibleDescription}</p> : null}
  </div>;
}
