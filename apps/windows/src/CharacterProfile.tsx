interface Props {
  label?: string;
  title: string;
  record?: string;
  description?: string;
  className?: string;
  imageSrc?: string;
  imageAlt?: string;
}

export function CharacterProfile({ label, title, record, description, className, imageSrc, imageAlt }: Props) {
  const classes = ["character-profile", imageSrc ? "has-portrait" : undefined, className].filter(Boolean).join(" ");
  const visibleRecord = record?.trim();
  const visibleDescription = description?.trim();

  return <div className={classes}>
    {imageSrc ? <img className="character-profile__portrait" src={imageSrc} alt={imageAlt ?? ""} /> : null}
    {label ? <span>{label}</span> : null}
    <strong>{title}</strong>
    {visibleRecord ? <small>{visibleRecord}</small> : null}
    {visibleDescription ? <p>{visibleDescription}</p> : null}
  </div>;
}
