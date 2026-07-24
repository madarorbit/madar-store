import type {IconName} from './Icons';
import {Icon} from './Icons';
import {Card} from './Enterprise';

export function ContentSections({sections}:{sections:{title:string;body:string;items?:string[];icon?:IconName}[]}){return <div className="grid gap-5">{sections.map(section=><Card key={section.title} className="p-6 sm:p-8"><div className="flex items-start gap-4">{section.icon&&<div className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-emerald-300/10 text-emerald-200"><Icon name={section.icon}/></div>}<div><h2 className="text-2xl font-black text-white">{section.title}</h2><p className="mt-4 leading-8 text-slate-300">{section.body}</p>{section.items&&<ul className="mt-5 grid gap-3">{section.items.map(item=><li key={item} className="flex gap-3 leading-7 text-slate-300"><Icon name="check" className="mt-1 h-5 w-5 shrink-0 text-emerald-300"/>{item}</li>)}</ul>}</div></div></Card>)}</div>}
