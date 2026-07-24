import Image from 'next/image';
import Link from 'next/link';
import type {AnchorHTMLAttributes,ButtonHTMLAttributes,HTMLAttributes,InputHTMLAttributes,ReactNode,SelectHTMLAttributes,TextareaHTMLAttributes} from 'react';
import {Icon,type IconName} from '@/components/ui/Icons';

export function cx(...values:Array<string|false|null|undefined>){return values.filter(Boolean).join(' ')}

export function Container({children,className=''}:{children:ReactNode;className?:string}){return <div className={cx('md-container',className)}>{children}</div>}
export function Page({children,className=''}:{children:ReactNode;className?:string}){return <main className={cx('md-shell',className)}>{children}</main>}
export function PageHeader({eyebrow,title,description,actions}:{eyebrow?:string;title:string;description?:string;actions?:ReactNode}){
 return <header className="md-page-header"><Container className="md-page-header-inner"><div className="grid items-end gap-6 lg:grid-cols-[1fr_auto]"><div>{eyebrow&&<span className="md-eyebrow">{eyebrow}</span>}<h1 className="md-title">{title}</h1>{description&&<p className="md-description">{description}</p>}</div>{actions&&<div className="md-cluster lg:justify-end">{actions}</div>}</div></Container></header>;
}
export function Section({children,className=''}:{children:ReactNode;className?:string}){return <section className={cx('md-container md-section',className)}>{children}</section>}
export function Panel({children,className=''}:{children:ReactNode;className?:string}){return <div className={cx('md-panel',className)}>{children}</div>}
export function Card({children,className='',interactive=false}:{children:ReactNode;className?:string;interactive?:boolean}){return <div className={cx('md-card',interactive&&'md-card-interactive',className)}>{children}</div>}
export function Grid({children,className='',auto=true}:{children:ReactNode;className?:string;auto?:boolean}){return <div className={cx('md-grid',auto&&'md-grid-auto',className)}>{children}</div>}

const buttonVariants={primary:'md-button-primary',secondary:'md-button-secondary',ghost:'md-button-ghost',danger:'md-button-danger'} as const;
type ButtonVariant=keyof typeof buttonVariants;
type ButtonSize='sm'|'md'|'lg';
function buttonClass(variant:ButtonVariant,size:ButtonSize,className?:string){return cx('md-button',buttonVariants[variant],size==='sm'&&'md-button-sm',size==='lg'&&'md-button-lg',className)}
export function Button({variant='primary',size='md',className,...props}:ButtonHTMLAttributes<HTMLButtonElement>&{variant?:ButtonVariant;size?:ButtonSize}){return <button className={buttonClass(variant,size,className)} {...props}/>} 
export function ButtonLink({href,children,variant='primary',size='md',className,...props}:AnchorHTMLAttributes<HTMLAnchorElement>&{href:string;children:ReactNode;variant?:ButtonVariant;size?:ButtonSize}){return <Link href={href} className={buttonClass(variant,size,className)} {...props}>{children}</Link>}

export function Field({label,help,error,children,className=''}:{label?:string;help?:string;error?:string;children:ReactNode;className?:string}){return <label className={cx('md-field',className)}>{label&&<span className="md-label">{label}</span>}{children}{error?<span className="text-sm font-bold text-rose-300">{error}</span>:help&&<span className="md-help">{help}</span>}</label>}
export function Input({className,...props}:InputHTMLAttributes<HTMLInputElement>){return <input className={cx('md-input',className)} {...props}/>} 
export function Select({className,children,...props}:SelectHTMLAttributes<HTMLSelectElement>){return <select className={cx('md-select',className)} {...props}>{children}</select>}
export function Textarea({className,...props}:TextareaHTMLAttributes<HTMLTextAreaElement>){return <textarea className={cx('md-textarea',className)} {...props}/>} 

const badgeVariants={default:'',brand:'md-badge-brand',success:'md-badge-success',warning:'md-badge-warning',danger:'md-badge-danger'} as const;
export function Badge({children,variant='default',className=''}:{children:ReactNode;variant?:keyof typeof badgeVariants;className?:string}){return <span className={cx('md-badge',badgeVariants[variant],className)}>{children}</span>}
export function Stat({label,value,detail,className=''}:{label:string;value:ReactNode;detail?:ReactNode;className?:string}){return <div className={cx('md-stat',className)}><span className="md-stat-label">{label}</span><strong className="md-stat-value">{value}</strong>{detail&&<span className="md-help">{detail}</span>}</div>}
export function EmptyState({title,description,icon='layers',action}:{title:string;description:string;icon?:IconName;action?:ReactNode}){return <div className="md-empty"><div className="max-w-lg"><span className="md-empty-icon mx-auto"><Icon name={icon}/></span><h2 className="mt-5 text-2xl font-black">{title}</h2><p className="mt-3 text-slate-400">{description}</p>{action&&<div className="mt-6 flex justify-center">{action}</div>}</div></div>}
export function Skeleton({className='h-5 w-full'}:{className?:string}){return <span aria-hidden="true" className={cx('md-skeleton block',className)}/>} 

const noticeVariants={default:'',success:'md-notice-success',warning:'md-notice-warning',danger:'md-notice-danger'} as const;
export function Notice({title,children,variant='default',icon='help'}:{title:string;children?:ReactNode;variant?:keyof typeof noticeVariants;icon?:IconName}){return <div className={cx('md-notice',noticeVariants[variant])}><span className="mt-0.5 text-emerald-300"><Icon name={icon}/></span><div><strong className="block">{title}</strong>{children&&<div className="mt-1 text-sm text-slate-300">{children}</div>}</div></div>}

export function TableWrap({children,className=''}:{children:ReactNode;className?:string}){return <div className={cx('md-table-wrap',className)}>{children}</div>}
export function Table({children,className='',...props}:HTMLAttributes<HTMLTableElement>){return <table className={cx('md-table',className)} {...props}>{children}</table>}
export function Tabs({items}:{items:Array<{label:string;href:string;active?:boolean}>}){return <nav className="md-tabs" aria-label="التبويبات">{items.map(item=><Link key={item.href} href={item.href} aria-current={item.active?'page':undefined} className={cx('md-tab',item.active&&'md-tab-active')}>{item.label}</Link>)}</nav>}
export function Breadcrumbs({items}:{items:Array<{label:string;href?:string}>}){return <nav className="md-breadcrumbs" aria-label="مسار الصفحة">{items.map((item,index)=><span key={`${item.label}-${index}`} className="contents">{index>0&&<span aria-hidden="true">/</span>}{item.href?<Link href={item.href}>{item.label}</Link>:<span aria-current="page" className="text-slate-200">{item.label}</span>}</span>)}</nav>}
export function Pagination({page,totalPages,hrefFor}:{page:number;totalPages:number;hrefFor:(page:number)=>string}){if(totalPages<=1)return null;const pages=Array.from({length:totalPages},(_,index)=>index+1).filter(value=>value===1||value===totalPages||Math.abs(value-page)<=1);return <nav className="md-pagination" aria-label="التنقل بين الصفحات">{page>1&&<Link className="md-page-button md-icon-directional" href={hrefFor(page-1)} aria-label="الصفحة السابقة"><Icon name="arrow" className="h-4 w-4"/></Link>}{pages.map((value,index)=><span className="contents" key={value}>{index>0&&value-pages[index-1]>1&&<span aria-hidden="true" className="px-1 text-slate-500">…</span>}<Link href={hrefFor(value)} aria-current={value===page?'page':undefined} className={cx('md-page-button',value===page&&'md-page-button-active')}>{value.toLocaleString('ar-YE')}</Link></span>)}{page<totalPages&&<Link className="md-page-button md-icon-directional" href={hrefFor(page+1)} aria-label="الصفحة التالية"><Icon name="arrow" className="h-4 w-4 rotate-180"/></Link>}</nav>}
export function Dropdown({label,children,className=''}:{label:ReactNode;children:ReactNode;className?:string}){return <details className={cx('group relative',className)}><summary className="md-button md-button-secondary list-none [&::-webkit-details-marker]:hidden">{label}<Icon name="arrow" className="h-4 w-4 rotate-90 transition group-open:-rotate-90"/></summary><div className="absolute left-0 z-40 mt-2 min-w-56 rounded-xl border border-white/10 bg-[#101625] p-2 shadow-2xl">{children}</div></details>}
export function SearchBox({action='/search',placeholder='ابحث في مَدار',className=''}:{action?:string;placeholder?:string;className?:string}){return <form action={action} role="search" className={cx('flex items-center gap-2 rounded-xl border border-white/10 bg-black/20 p-2',className)}><Icon name="search" className="mr-2 h-5 w-5 text-slate-400"/><label className="sr-only" htmlFor="md-enterprise-search">البحث</label><input id="md-enterprise-search" name="q" type="search" className="min-w-0 flex-1 border-0 bg-transparent px-2 text-white outline-none placeholder:text-slate-500" placeholder={placeholder}/><Button type="submit" size="sm">بحث</Button></form>}
export function OrbyBadge({imageSrc='/brand/orby-assistant.svg',label='أوربي'}:{imageSrc?:string;label?:string}){return <span className="md-orby-chip"><Image src={imageSrc} alt="صورة أوربي" width={32} height={32} unoptimized className="md-orby-avatar"/><span>{label}</span></span>}
export function Divider(){return <hr className="border-0 border-t border-white/10"/>}
