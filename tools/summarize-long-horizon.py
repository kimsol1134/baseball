"""Summarize the current-rule audit CSVs; never writes a game save."""
from pathlib import Path
import csv
import json
import statistics as stats
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root = Path(__file__).resolve().parents[1] / 'artifacts/android-compose/long-horizon'

def read(name):
    with (root / name).open() as f:
        rows = list(csv.DictReader(f))
    assert all(None not in r and None not in r.values() for r in rows)
    return rows

def total(rows, key): return sum(int(r[key]) for r in rows)
def mean(rows, key): return stats.mean(int(r[key]) for r in rows)
def display(n): return max(1, min(100, ((max(20, min(80, int(n)))-20)*100+30)//60))
def ratings(row, prefix=''): return sum(display(row[prefix+k]) for k in ('stuff','command','movement','stamina'))
def ratio(rows, numerator, factor=27): return total(rows,numerator)*factor/total(rows,'outs')

pro, careers, school = read('pro-seasons.csv'), read('pro-careers.csv'), read('school-lives.csv')
assert len(pro) == 360 and len(careers) == 18 and len(school) == 126
summary = {'proCareers':len(careers), 'proSeasons':len(pro), 'schoolLives':len(school), 'schoolCases':18, 'proPolicies':{}, 'schoolIntensities':{}}
for policy in ('power','balanced','recovery'):
    rows=[r for r in pro if r['policy']==policy]
    complete=[r for r in careers if r['policy']==policy]
    summary['proPolicies'][policy] = {
        'gamesPerSeason':round(mean(rows,'games'),2), 'injuredWeeksPerSeason':round(mean(rows,'injured_weeks'),2),
        'hallOfFameScores':[int(r['hall_of_fame_score']) for r in complete],
        'hallOfFameInductions':sum(int(r['hall_of_fame_score'])>=70 for r in complete),
        'year1K9':round(ratio([r for r in rows if r['season']=='1'],'k'),2),
        'year20K9':round(ratio([r for r in rows if r['season']=='20'],'k'),2),
        'years':[{ 'season':y, 'displayedRatingTotal':round(stats.mean(ratings(r) for r in rows if int(r['season'])==y),2),
                   'k9':round(ratio([r for r in rows if int(r['season'])==y],'k'),2)} for y in range(1,21)]}
for intensity in ('light','standard','intensive'):
    rows=[r for r in school if r['intensity']==intensity]
    summary['schoolIntensities'][intensity]={
        'meanDisplayedRatingGain':round(stats.mean(ratings(r,'end_')-ratings(r,'start_') for r in rows),2),
        'recoveryTrainingPercent':round(total(rows,'recovery_trainings')/total(rows,'trainings')*100,2),
        'drafted':sum(r['drafted']=='true' for r in rows), 'lives':len(rows),
        'learnedSkillsRange':[min(int(r['end_skills']) for r in rows),max(int(r['end_skills']) for r in rows)]}
summary['rebirth']={preset:[{'life':life,'displayedStartTotal':round(stats.mean(ratings(r,'start_') for r in school if r['preset']==preset and int(r['life'])==life),2),
                           'appliedRanks':sorted({int(r['applied_lineage_rank']) for r in school if r['preset']==preset and int(r['life'])==life})} for life in range(1,8)]
                     for preset in ('power_prospect','precision_commander')}
(root/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')

plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False,'axes.titleweight':'bold'})
fig, ax = plt.subplots(2,2,figsize=(12,8),layout='constrained')
colors={'power':'#d16a34','balanced':'#285ce4','recovery':'#21876f'}
labels={'power':'Power focus','balanced':'Balanced','recovery':'Recovery first'}
for p in colors:
    values=summary['proPolicies'][p]['years']
    ax[0,0].plot([v['season'] for v in values],[v['displayedRatingTotal'] for v in values],label=labels[p],color=colors[p],linewidth=2)
    ax[0,1].plot([v['season'] for v in values],[v['k9'] for v in values],label=labels[p],color=colors[p],linewidth=2)
ax[0,0].set(title='Career growth',xlabel='Season',ylabel='Displayed rating total (4 attributes)',ylim=(0,400),xticks=[1,5,10,15,20]);ax[0,0].legend(frameon=False)
ax[0,1].set(title='Strikeouts increasingly dominate late careers',xlabel='Season',ylabel='K / 9 innings',ylim=(0,27),xticks=[1,5,10,15,20])
ax[1,0].bar([labels[p] for p in colors],[summary['proPolicies'][p]['injuredWeeksPerSeason'] for p in colors],color=list(colors.values()))
ax[1,0].set(title='Time spent injured',ylabel='Weeks per season')
for preset,label,color in [('power_prospect','Power pitcher','#285ce4'),('precision_commander','Command pitcher','#9662ba')]:
    values=summary['rebirth'][preset]
    ax[1,1].plot([v['life'] for v in values],[v['displayedStartTotal'] for v in values],marker='o',label=label,color=color,linewidth=2)
ax[1,1].set(title='Starting strength across rebirths',xlabel='Life',ylabel='Displayed starting rating total',ylim=(100,180),xticks=range(1,8));ax[1,1].legend(frameon=False)
for a in ax.flat: a.grid(axis='y',alpha=.18);a.set_axisbelow(True)
fig.suptitle('Long-horizon balance audit: 360 pro seasons / 126 school lives',fontsize=15,fontweight='bold')
fig.savefig(root/'balance-overview.png',dpi=160)
plt.close(fig)
print(json.dumps(summary,ensure_ascii=False,indent=2))
