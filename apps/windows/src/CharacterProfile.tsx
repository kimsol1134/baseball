interface Props {
  label?: string;
  title: string;
  record?: string;
  description?: string;
  className?: string;
}

export function CharacterProfile({ label, title, record, description, className }: Props) {
  const classes = ["character-profile", className].filter(Boolean).join(" ");
  const visibleRecord = record?.trim();
  const visibleDescription = description?.trim();

  return <div className={classes}>
    {label ? <span>{label}</span> : null}
    <strong>{title}</strong>
    {visibleRecord ? <small>{visibleRecord}</small> : null}
    {visibleDescription ? <p>{visibleDescription}</p> : null}
  </div>;
}
