export type Locale = 'ko' | 'en' | 'ja';
export const locales: Locale[] = ['ko', 'en', 'ja'];
export const folders = {ko:'ko-KR', en:'en-US', ja:'ja-JP'};
export const brand = {ko:'야구 못하면 또 환생함', en:'Mound Reborn', ja:'野球がダメならまた転生'};
export const promise = {ko:'한 구는 손끝으로, 인생은 내 선택으로', en:'Your pitch. Your choices. Your baseball life.', ja:'一球は指先で。人生は選択で。'};
export const shots = [
 {asset:'pitch', topic:{ko:'직접 던지는 야구 RPG',en:'A BASEBALL CAREER RPG',ja:'自分で投げる野球RPG'}, lines:{ko:['한 구의 승부,','네 손끝으로'],en:['One pitch.','All in your hands.'],ja:['勝負の一球を、','その指先で。']}},
 {asset:'training', topic:{ko:'훈련과 성장',en:'TRAIN YOUR WAY',ja:'練習と成長'}, lines:{ko:['원하는 투수로','키워가는 재미'],en:['Build the pitcher','you want to be.'],ja:['なりたい投手へ、','育てる楽しさ。']}},
 {asset:'legacy', topic:{ko:'환생과 유산',en:'REBIRTH & LEGACY',ja:'転生と継承'}, lines:{ko:['끝난 줄 알았지?','다시, 마운드로'],en:['An ending?','Another beginning.'],ja:['終わりだと思った？','もう一度、マウンドへ。']}},
 {asset:'conversation', topic:{ko:'관계와 선택',en:'CHOICES THAT MATTER',ja:'仲間と選択'}, lines:{ko:['누구의 말을 믿을지,','그것도 네 선택'],en:['Whose advice','will you follow?'],ja:['誰の言葉を信じる？','それも、君の選択。']}},
 {asset:'draft', topic:{ko:'고교에서 드래프트까지',en:'THREE YEARS. ONE DRAFT.',ja:'高校からドラフトへ'}, lines:{ko:['쌓아 온 3년이','드래프트의 결과로'],en:['Three years of work.','One draft day.'],ja:['積み重ねた3年間。','ドラフトで、その答えを。']}},
 {asset:'contract', topic:{ko:'프로의 첫 계약',en:'YOUR FIRST PRO CONTRACT',ja:'プロとしての最初の契約'}, lines:{ko:['꿈꾸던 프로 계약,','조건부터 내 선택'],en:['Your pro career.','Your first contract.'],ja:['夢見たプロ契約。','条件も、自分で選ぶ。']}},
 {asset:'pro-week', topic:{ko:'프로 시즌의 갈림길',en:'LIFE IN THE PROS',ja:'プロのシーズンへ'}, lines:{ko:['프로의 시즌도','매주 다른 선택'],en:['A new season.','More choices to make.'],ja:['プロのシーズンも、','毎週が選択の連続。']}},
 {asset:'album', topic:{ko:'기록과 선수 앨범',en:'A CAREER TO REMEMBER',ja:'記録と選手アルバム'}, lines:{ko:['한 투수의 기록이','한 편의 이야기로'],en:['Every record','tells your story.'],ja:['一人の投手の記録が、','一つの物語になる。']}},
] as const;
export const videoOrder = [0,2,1,3,4,5,6,7];
export const sceneDurations = [188,128,128,98,98,98,128,90];
