import React from "react";
import {AbsoluteFill, Img, staticFile} from "remotion";
import {japaneseFontStack, palette} from "../theme";

export type JapaneseScreenAsset =
  | "pitch-strike"
  | "release-gesture"
  | "draft-failure"
  | "rebirth"
  | "next-life"
  | "pitch-decision"
  | "legacy-choice"
  | "draft-success";

const line = "rgba(138,156,144,.28)";
const soft = "rgba(14,21,18,.92)";

const StatusBar: React.FC<{time?: string}> = ({time = "12:00"}) => (
  <div
    style={{
      height: "4.7%",
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "0 5.2%",
      color: palette.bone,
      fontSize: ".82em",
      fontWeight: 800,
      letterSpacing: ".02em",
    }}
  >
    <span>{time}</span>
    <span style={{fontSize: ".68em", letterSpacing: ".2em"}}>●●●　⌁　▰</span>
  </div>
);

const Hairline: React.FC = () => <div style={{height: 1, background: line}} />;

const Button: React.FC<{children: React.ReactNode; muted?: boolean}> = ({children, muted = false}) => (
  <div
    style={{
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      minHeight: "3.1em",
      borderRadius: ".55em",
      background: muted ? palette.surfaceRaised : palette.lime,
      color: muted ? palette.bone : palette.ink,
      fontWeight: 900,
      fontSize: ".9em",
      boxShadow: muted ? `inset 0 0 0 1px ${line}` : "0 .35em 1.2em rgba(183,243,107,.12)",
    }}
  >
    {children}
  </div>
);

const ZoneGrid: React.FC<{large?: boolean; marker?: boolean}> = ({large = false, marker = true}) => (
  <div
    style={{
      position: "relative",
      width: large ? "64%" : "54%",
      aspectRatio: "1 / 1",
      margin: "0 auto",
      border: ".16em solid rgba(241,244,238,.74)",
      borderRadius: ".25em",
      background:
        "linear-gradient(90deg, transparent 32.7%, rgba(241,244,238,.18) 33%, rgba(241,244,238,.18) 33.7%, transparent 34%), linear-gradient(90deg, transparent 65.7%, rgba(241,244,238,.18) 66%, rgba(241,244,238,.18) 66.7%, transparent 67%), linear-gradient(0deg, transparent 32.7%, rgba(241,244,238,.18) 33%, rgba(241,244,238,.18) 33.7%, transparent 34%), linear-gradient(0deg, transparent 65.7%, rgba(241,244,238,.18) 66%, rgba(241,244,238,.18) 66.7%, transparent 67%), #243C2D",
      boxShadow: "0 1em 3em rgba(0,0,0,.35)",
    }}
  >
    {marker ? (
      <>
        <div
          style={{
            position: "absolute",
            left: "68%",
            top: "15%",
            width: "17%",
            aspectRatio: "1 / 1",
            borderRadius: "50%",
            border: ".12em solid rgba(217,113,75,.8)",
            background: "rgba(217,113,75,.12)",
          }}
        />
        <div
          style={{
            position: "absolute",
            left: "74%",
            top: "21%",
            width: "5%",
            aspectRatio: "1 / 1",
            borderRadius: "50%",
            background: palette.bone,
            boxShadow: `0 0 1em ${palette.lime}`,
          }}
        />
      </>
    ) : null}
  </div>
);

const PitchHeader: React.FC = () => (
  <div style={{padding: "1.3% 4.6% 1.5%"}}>
    <div style={{color: palette.muted, fontSize: ".67em", fontWeight: 800}}>2年・第2週</div>
    <div style={{display: "flex", alignItems: "baseline", gap: ".75em", marginTop: ".35em"}}>
      <strong style={{color: palette.lime, fontSize: ".92em"}}>1回　8球</strong>
      <span style={{color: palette.bone, fontSize: ".72em"}}>1アウト　走者なし</span>
      <span style={{marginLeft: "auto", color: palette.muted, fontSize: ".68em"}}>残り31球</span>
    </div>
  </div>
);

const PitchStrikeScreen: React.FC = () => (
  <>
    <StatusBar time="13:30" />
    <PitchHeader />
    <Hairline />
    <div style={{padding: "5% 5% 3%", textAlign: "center"}}>
      <div style={{color: palette.lime, fontSize: "1.75em", fontWeight: 900, letterSpacing: "-.04em"}}>
        見逃しストライク
      </div>
      <div style={{marginTop: "5%"}}>
        <ZoneGrid large />
      </div>
    </div>
    <div
      style={{
        margin: "0 4.5%",
        padding: "4%",
        borderRadius: ".75em",
        background: "#123021",
        boxShadow: `inset 0 0 0 1px ${line}`,
      }}
    >
      <div style={{color: palette.lime, fontSize: ".63em", fontWeight: 900}}>球種・ストレート</div>
      <div style={{marginTop: ".6em", color: palette.bone, fontSize: ".78em", lineHeight: 1.55}}>
        低めのコースへ投げ込みました。打者は反応できません。
      </div>
      <div style={{display: "flex", alignItems: "baseline", gap: ".35em", marginTop: ".45em"}}>
        <strong style={{color: palette.lime, fontSize: "1.75em"}}>107.5</strong>
        <span style={{color: palette.lime, fontSize: ".65em", fontWeight: 800}}>km/h</span>
      </div>
    </div>
    <div style={{position: "absolute", left: "4.5%", right: "4.5%", bottom: "4.2%"}}>
      <Button>次へ</Button>
    </div>
  </>
);

const PitchDecisionScreen: React.FC<{gesture?: boolean}> = ({gesture = false}) => (
  <>
    <StatusBar time="13:30" />
    <PitchHeader />
    <Hairline />
    <div style={{padding: "3.6% 4.6%"}}>
      <div style={{display: "flex", alignItems: "center", gap: ".7em"}}>
        <strong style={{fontSize: "1.05em", color: palette.bone}}>強打者</strong>
        <span
          style={{
            padding: ".2em .55em",
            borderRadius: "999px",
            color: palette.ink,
            background: palette.lime,
            fontSize: ".58em",
            fontWeight: 900,
          }}
        >
          対戦中
        </span>
      </div>
      <div style={{marginTop: ".5em", color: palette.muted, fontSize: ".68em"}}>
        ミート 38・長打 41・選球眼 47
      </div>
      <Hairline />
      <div style={{marginTop: "3.5%", color: palette.lime, fontSize: ".62em", fontWeight: 900}}>
        捕手のサイン
      </div>
      <div style={{marginTop: ".55em", color: palette.bone, fontSize: ".9em", lineHeight: 1.45}}>
        カーブ・低め外角・空振り狙い
      </div>
      <div style={{marginTop: ".35em", color: palette.muted, fontSize: ".62em", lineHeight: 1.5}}>
        打者は前の速球を意識しています。同じ配球は読まれます。
      </div>
      <div style={{display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: ".35em", marginTop: "4%"}}>
        {["速球", "スライダー", "カーブ", "チェンジアップ"].map((pitch) => (
          <div
            key={pitch}
            style={{
              padding: ".75em .2em",
              textAlign: "center",
              borderRadius: ".35em",
              color: pitch === "カーブ" ? palette.ink : palette.bone,
              background: pitch === "カーブ" ? palette.lime : palette.surfaceRaised,
              fontSize: ".58em",
              fontWeight: 900,
              boxShadow: `inset 0 0 0 1px ${line}`,
            }}
          >
            {pitch}
          </div>
        ))}
      </div>
      <div style={{marginTop: "5%"}}>
        <ZoneGrid />
      </div>
    </div>
    {gesture ? (
      <div
        style={{
          position: "absolute",
          left: "4.5%",
          right: "4.5%",
          bottom: "4.4%",
          padding: "4% 5% 5%",
          borderRadius: "1em",
          textAlign: "center",
          background: "rgba(20,29,25,.98)",
          boxShadow: `inset 0 0 0 1px ${line}, 0 -2em 4em rgba(7,12,10,.8)`,
        }}
      >
        <div style={{color: palette.lime, fontSize: ".68em", fontWeight: 900}}>ワインドアップ</div>
        <div style={{marginTop: ".35em", color: palette.bone, fontSize: "1em", fontWeight: 900}}>
          押す → 引く → 離す
        </div>
        <div style={{marginTop: ".6em", color: palette.muted, fontSize: ".6em"}}>
          タイミングを合わせてリリース
        </div>
      </div>
    ) : (
      <div style={{position: "absolute", left: "4.5%", right: "4.5%", bottom: "4.2%"}}>
        <Button>投げる</Button>
      </div>
    )}
  </>
);

const PortraitGround: React.FC = () => (
  <>
    <Img
      src={staticFile("portraits/player-4.jpg")}
      style={{width: "100%", height: "100%", objectFit: "cover", opacity: 0.2}}
    />
    <AbsoluteFill
      style={{
        background:
          "linear-gradient(180deg, rgba(7,12,10,.4), rgba(7,12,10,.94) 78%), radial-gradient(70% 50% at 70% 34%, rgba(183,243,107,.1), transparent 70%)",
      }}
    />
  </>
);

const DraftFailureScreen: React.FC = () => (
  <>
    <PortraitGround />
    <StatusBar />
    <div
      style={{
        position: "absolute",
        left: "6%",
        right: "6%",
        top: "39%",
        textAlign: "center",
      }}
    >
      <div style={{color: palette.muted, fontSize: ".62em", fontWeight: 900, letterSpacing: ".12em"}}>
        全ラウンド終了
      </div>
      <div style={{marginTop: ".9em", color: palette.bone, fontSize: "1.45em", fontWeight: 900}}>
        名前は呼ばれませんでした
      </div>
      <div style={{marginTop: ".75em", color: palette.muted, fontSize: ".7em", lineHeight: 1.7}}>
        3年間はここで終わります。
        <br />
        次の投手に何を残すか選びましょう。
      </div>
    </div>
    <div style={{position: "absolute", left: "4.5%", right: "4.5%", bottom: "4.2%"}}>
      <Button>続ける</Button>
    </div>
  </>
);

const RebirthScreen: React.FC = () => (
  <>
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(circle at 18% 28%, rgba(241,244,238,.7) 0 1px, transparent 2px), radial-gradient(circle at 76% 22%, rgba(241,244,238,.7) 0 1px, transparent 2px), radial-gradient(circle at 63% 68%, rgba(183,243,107,.45) 0 1px, transparent 2px), linear-gradient(160deg, #07100d 0%, #0a1716 46%, #111c25 100%)",
        backgroundSize: "31px 37px, 43px 47px, 53px 59px, auto",
      }}
    />
    <div
      style={{
        position: "absolute",
        width: "115%",
        height: ".18em",
        left: "-5%",
        top: "43%",
        rotate: "-24deg",
        background: "linear-gradient(90deg, transparent, rgba(241,244,238,.92), transparent)",
        boxShadow: "0 0 2.5em rgba(183,243,107,.45)",
      }}
    />
    <StatusBar />
    <div style={{position: "absolute", left: "8%", right: "8%", top: "48%", textAlign: "center"}}>
      <div style={{color: palette.amber, fontSize: ".62em", fontWeight: 900}}>記憶を受け継ぎます</div>
      <div style={{marginTop: ".5em", color: palette.bone, fontSize: "1.9em", fontWeight: 900}}>2人目の投手</div>
      <div style={{marginTop: ".65em", color: palette.muted, fontSize: ".72em"}}>高校1年の春へ戻ります</div>
    </div>
  </>
);

const NextLifeScreen: React.FC = () => (
  <>
    <StatusBar />
    <div style={{padding: "2.5% 4.6% 0"}}>
      <div style={{color: palette.lime, fontSize: ".6em", fontWeight: 900}}>2人目の投手・1年・地区予選</div>
      <div style={{marginTop: ".45em", color: palette.bone, fontSize: "1.35em", fontWeight: 900}}>昼下がりのマウンド</div>
      <div style={{display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: ".55em", marginTop: "3%"}}>
        {[["登板", "5"], ["投球回", "50"], ["失点", "0"]].map(([label, value]) => (
          <div key={label} style={{padding: "1em", borderRadius: ".55em", background: soft, boxShadow: `inset 0 0 0 1px ${line}`}}>
            <div style={{color: palette.muted, fontSize: ".56em"}}>{label}</div>
            <strong style={{display: "block", marginTop: ".2em", color: palette.bone, fontSize: "1.45em"}}>{value}</strong>
          </div>
        ))}
      </div>
      <div style={{marginTop: "4%", color: palette.lime, fontSize: ".62em", fontWeight: 900}}>継承</div>
      <div style={{marginTop: ".5em", color: palette.bone, fontSize: ".74em", lineHeight: 1.7}}>
        前の投手の手紙と記憶を受け継いで、もう一度始めます。
      </div>
      <div style={{marginTop: "4%", display: "grid", gap: ".7em"}}>
        {["前の投手から届いた手紙", "マウンドの残響", "低めへの執念"].map((title, index) => (
          <div
            key={title}
            style={{
              display: "flex",
              alignItems: "center",
              gap: ".9em",
              padding: "1em",
              borderRadius: ".65em",
              background: index === 1 ? "rgba(232,178,76,.12)" : soft,
              boxShadow: `inset 0 0 0 1px ${index === 1 ? "rgba(232,178,76,.5)" : line}`,
            }}
          >
            <Img src={staticFile(`portraits/player-${index + 1}.jpg`)} style={{width: "2.4em", height: "2.4em", borderRadius: ".4em", objectFit: "cover"}} />
            <div>
              <strong style={{color: palette.bone, fontSize: ".75em"}}>{title}</strong>
              <div style={{marginTop: ".35em", color: palette.muted, fontSize: ".57em"}}>
                次の投手の成長に影響します
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
    <div style={{position: "absolute", left: "4.5%", right: "4.5%", bottom: "4.2%"}}>
      <Button>次の人生を始める</Button>
    </div>
  </>
);

const LegacyChoiceScreen: React.FC = () => (
  <>
    <StatusBar />
    <div style={{padding: "2.8% 4.6% 0"}}>
      <div style={{color: palette.muted, fontSize: ".62em", fontWeight: 900}}>1人目の投手・3年</div>
      <div style={{marginTop: ".5em", color: palette.bone, fontSize: "1.25em", fontWeight: 900}}>次の投手へ残すもの</div>
      <div style={{marginTop: "3%", padding: "1em", borderRadius: ".65em", background: soft, lineHeight: 1.75, color: palette.bone, fontSize: ".67em"}}>
        3年間の記録から、ひとつだけ次の人生へ残せます。
        <br />
        技術、記憶、それとも大切な人との約束。
      </div>
      <div style={{display: "grid", gap: ".75em", marginTop: "4%"}}>
        {[
          ["捕手のノート", "打者の癖を読む力が上がる"],
          ["マウンドの残響", "勝負所で制球が安定する"],
          ["最後の手紙", "次の投手の成長を後押しする"],
        ].map(([title, body], index) => (
          <div
            key={title}
            style={{
              padding: "1.05em",
              borderRadius: ".7em",
              background: index === 1 ? "rgba(232,178,76,.13)" : palette.surfaceRaised,
              boxShadow: `inset 0 0 0 1px ${index === 1 ? "rgba(232,178,76,.7)" : line}`,
            }}
          >
            <div style={{display: "flex", alignItems: "center", justifyContent: "space-between"}}>
              <strong style={{color: index === 1 ? palette.amber : palette.bone, fontSize: ".8em"}}>{title}</strong>
              <span style={{color: index === 1 ? palette.amber : palette.muted, fontSize: ".58em"}}>{index === 1 ? "選択中" : "選ぶ"}</span>
            </div>
            <div style={{marginTop: ".45em", color: palette.muted, fontSize: ".6em", lineHeight: 1.55}}>{body}</div>
          </div>
        ))}
      </div>
    </div>
    <div style={{position: "absolute", left: "4.5%", right: "4.5%", bottom: "4.2%"}}>
      <Button>この記憶を残す</Button>
    </div>
  </>
);

const DraftSuccessScreen: React.FC = () => (
  <>
    <PortraitGround />
    <StatusBar time="15:56" />
    <div style={{position: "absolute", left: "7%", right: "7%", top: "40%", textAlign: "center"}}>
      <div style={{color: "#6AA9FF", fontSize: ".62em", fontWeight: 900}}>ドラフト指名</div>
      <div style={{marginTop: ".35em", color: "#6AA9FF", fontSize: "1.85em", fontWeight: 900}}>ソウル・コメッツ</div>
      <div style={{marginTop: ".65em", color: palette.bone, fontSize: ".9em", fontWeight: 900}}>4巡目・全体37位</div>
      <div style={{marginTop: ".55em", color: palette.muted, fontSize: ".72em"}}>契約金 1億2,000万ウォン</div>
    </div>
    <div style={{position: "absolute", left: "4.5%", right: "4.5%", bottom: "4.2%"}}>
      <Button>続ける</Button>
    </div>
  </>
);

export const JapaneseAppScreen: React.FC<{asset: JapaneseScreenAsset}> = ({asset}) => (
  <AbsoluteFill
    style={{
      overflow: "hidden",
      background: palette.ink,
      color: palette.bone,
      fontFamily: japaneseFontStack,
      fontSize: "clamp(18px, 2.75vw, 42px)",
      lineHeight: 1.25,
    }}
  >
    {asset === "pitch-strike" ? <PitchStrikeScreen /> : null}
    {asset === "pitch-decision" ? <PitchDecisionScreen /> : null}
    {asset === "release-gesture" ? <PitchDecisionScreen gesture /> : null}
    {asset === "draft-failure" ? <DraftFailureScreen /> : null}
    {asset === "rebirth" ? <RebirthScreen /> : null}
    {asset === "next-life" ? <NextLifeScreen /> : null}
    {asset === "legacy-choice" ? <LegacyChoiceScreen /> : null}
    {asset === "draft-success" ? <DraftSuccessScreen /> : null}
  </AbsoluteFill>
);
