export type Locale = 'ko' | 'en' | 'ja';
export const scenes = ['pitch','growth','decision','contract','records','album','legacy','rebirth'] as const;
export type Scene = typeof scenes[number];
export type ShotCopy = {tag:string;title:[string,string];detail:string;video:string};
export const brands:Record<Locale,string> = {ko:'야구 못하면 또 환생함',en:'MOUND REBORN',ja:'野球がダメならまた転生'};
export const copy:Record<Locale,ShotCopy[]> = {
 ko:[
  {tag:'직접 던지는 투수 육성 RPG',title:['직접 던져야,','내 야구다.'],detail:'누르고, 노리고, 타이밍에 맞춰 놓아라.',video:'누르고. 노리고. 놓아라.'},
  {tag:'훈련 · 성장 · 각성',title:['키운 만큼,','공이 달라진다.'],detail:'제구부터 구위까지, 나만의 투수를 키워라.',video:'키운 만큼, 공이 달라진다.'},
  {tag:'선택이 쌓이는 선수 생활',title:['선택 하나로,','다른 선수 인생.'],detail:'무엇을 지키고, 어디에 도전할 것인가.',video:'선택으로 만드는 선수 생활.'},
  {tag:'고교에서 프로까지',title:['꿈꾸던 무대.','내 첫 프로 계약.'],detail:'이름이 불린 뒤에도, 야구는 계속된다.',video:'고교를 넘어, 프로의 마운드로.'},
  {tag:'시즌 · 통산 · 성장 기록',title:['삼진도, 실점도.','전부 내 기록이다.'],detail:'쌓아 온 이닝과 성장의 흔적을 돌아봐라.',video:'삼진도, 실점도. 내 기록으로.'},
  {tag:'기억에 남는 공을 다시 보기',title:['잊지 못할 한 구.','다시 꺼내 본다.'],detail:'공이 지나간 궤적까지, 내 야구의 한 장면.',video:'잊지 못할 한 구를 다시.'},
  {tag:'은퇴 이후에도 이어지는 성장',title:['끝난 선수 생활이','다음 재능이 된다.'],detail:'남길 기억을 골라, 다음 투수에게 이어줘라.',video:'남길 기억을 고른다.'},
  {tag:'환생 · 계승 · 다시 도전',title:['이번 생엔,','더 높이 올라간다.'],detail:'지난 야구를 발판 삼아, 다시 마운드로.',video:'다음 생의 마운드가 기다린다.'},
 ],
 en:[
  {tag:'A BASEBALL CAREER RPG',title:['Make every pitch','your own.'],detail:'Hold. Aim. Release at just the right moment.',video:'Hold. Aim. Let it fly.'},
  {tag:'TRAIN · GROW · AWAKEN',title:['Build your pitcher.','Own the mound.'],detail:'Shape your control, your stuff, your style.',video:'Build the pitcher you want to be.'},
  {tag:'YOUR CHOICES SHAPE YOUR CAREER',title:['One choice.','A different career.'],detail:'Decide what to protect—and what to chase.',video:'Your choices. Your career.'},
  {tag:'FROM HIGH SCHOOL TO THE PROS',title:['The call you wanted.','Your first pro deal.'],detail:'Getting drafted is only the beginning.',video:'Earn your place in the pros.'},
  {tag:'SEASON · CAREER · GROWTH',title:['Every strikeout.','Every season.'],detail:'Look back on the innings that made you.',video:'Every inning becomes your story.'},
  {tag:'RELIVE YOUR MEMORABLE PITCHES',title:['That one pitch.','Watch it again.'],detail:'Revisit the flight, the location, the moment.',video:'Relive the pitches that stayed with you.'},
  {tag:'LEAVE SOMETHING BEHIND',title:['One career ends.','Its legacy doesn’t.'],detail:'Choose the memories your next pitcher inherits.',video:'Choose what your next life inherits.'},
  {tag:'REBIRTH · LEGACY · ANOTHER SHOT',title:['Start again.','Come back stronger.'],detail:'Carry your past onto a new mound.',video:'A new life. Another shot at the mound.'},
 ],
 ja:[
  {tag:'自分で投げる、投手育成RPG',title:['その一球を、','自分の手で。'],detail:'押して、狙って、タイミングよく離す。',video:'押して、狙って、離す。'},
  {tag:'練習・成長・覚醒',title:['育てた分だけ、','投球が変わる。'],detail:'制球も球威も、自分だけの投手へ。',video:'育てた分だけ、投球が変わる。'},
  {tag:'選択でつくる野球人生',title:['ひとつの選択が、','人生を変える。'],detail:'何を守り、何に挑むか。決めるのは自分。',video:'選択でつくる、自分の野球人生。'},
  {tag:'高校からプロのマウンドへ',title:['夢見た舞台。','初めてのプロ契約。'],detail:'名前を呼ばれた、その先にも野球は続く。',video:'高校から、プロのマウンドへ。'},
  {tag:'シーズン・通算・成長の記録',title:['奪三振も、失点も。','すべて自分の記録。'],detail:'積み重ねたイニングと成長を振り返る。',video:'一つひとつの記録が、自分の物語に。'},
  {tag:'心に残る投球をリプレイ',title:['あの一球を、','もう一度。'],detail:'軌道も、コースも、あの瞬間も。',video:'忘れられない一球を、もう一度。'},
  {tag:'引退の先にも、成長がある',title:['終えた野球人生が、','次の力になる。'],detail:'残したい記憶を選び、次の投手に託す。',video:'次の人生に残す記憶を選ぶ。'},
  {tag:'転生・継承・再挑戦',title:['次の人生で、','もっと高みへ。'],detail:'前の人生を力に、またマウンドへ。',video:'次の人生でも、またマウンドへ。'},
 ],
};
