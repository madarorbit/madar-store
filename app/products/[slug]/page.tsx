import type {Metadata} from 'next';
import Link from 'next/link';
import {notFound} from 'next/navigation';
import PageShell from '@/components/ui/PageShell';
import {Breadcrumbs} from '@/components/ui/Breadcrumbs';
import {Section} from '@/components/ui/Section';
import {Badge,Card} from '@/components/ui/Enterprise';
import {supabaseFetch} from '@/src/lib/supabase/server';
import {catalogImageUrl} from '@/src/lib/catalog-media';
import {arabicDisplay,arabicList,arabicMoney} from '@/src/lib/arabic-display';
import {Icon} from '@/components/ui/Icons';
import AddToCart from '@/components/cart/AddToCart';

type Props={params:Promise<{slug:string}>};
export const dynamic='force-dynamic';
async function product(slug:string){const rows=await supabaseFetch(`/rest/v1/products?slug=eq.${encodeURIComponent(slug)}&status=eq.published&select=id,name,slug,short_description,long_description,price,currency,features,includes,delivery_type,thumbnail_url`);return rows?.[0]}
export async function generateMetadata({params}:Props):Promise<Metadata>{try{const item=await product((await params).slug);return item?{title:arabicDisplay(item.name),description:arabicDisplay(item.short_description)}:{title:'منتج غير موجود'}}catch{return{title:'تعذر تحميل المنتج'}}}

export default async function ProductPage({params}:Props){
 let item;try{item=await product((await params).slug)}catch{throw new Error('تعذر الاتصال بقاعدة البيانات.')}if(!item)notFound();
 const image=catalogImageUrl(item.thumbnail_url),name=arabicDisplay(item.name),description=arabicDisplay(item.long_description||item.short_description),features=arabicList(item.features),includes=arabicList(item.includes);
 return <PageShell><Section><Breadcrumbs items={[{label:'المتجر',href:'/store'},{label:'المنتجات',href:'/products'},{label:name}]}/><div className="mt-7 grid items-start gap-10 lg:grid-cols-[minmax(0,1fr)_24rem]"><article><div className="relative mb-8 aspect-[16/9] overflow-hidden rounded-[2rem] border border-white/10 bg-[#11182B]">{image?<div className="absolute inset-0 bg-cover bg-center" style={{backgroundImage:`url("${image.replace(/["\\]/g,'')}")`}} role="img" aria-label={`صورة ${name}`}/>:<div className="absolute inset-0 grid place-items-center bg-[radial-gradient(circle_at_30%_20%,rgba(124,77,255,.55),transparent_35%),radial-gradient(circle_at_70%_75%,rgba(50,214,189,.38),transparent_38%)]"><Icon name="layers" className="h-24 w-24 text-white"/></div>}</div><Badge variant="success">منتج رقمي من مَدار</Badge><h1 className="mt-4 text-4xl font-black leading-tight sm:text-6xl">{name}</h1><p className="mt-6 text-lg leading-9 text-slate-300">{description}</p><h2 className="mt-10 text-2xl font-black">المزايا</h2><ul className="mt-5 grid gap-3 sm:grid-cols-2">{features.map(feature=><li className="md-card flex gap-3 p-4 text-slate-300" key={feature}><Icon name="check" className="h-5 w-5 shrink-0 text-emerald-300"/>{feature}</li>)}</ul>{includes.length>0&&<><h2 className="mt-10 text-2xl font-black">محتويات المنتج</h2><ul className="mt-4 grid gap-3 text-slate-300">{includes.map(value=><li key={value} className="flex gap-3"><Icon name="check" className="h-5 w-5 shrink-0 text-violet-200"/>{value}</li>)}</ul></>}</article><Card className="h-fit lg:sticky lg:top-24"><p className="text-sm text-slate-400">السعر</p><p className="mt-2 text-4xl font-black text-emerald-300">{arabicMoney(item.price,item.currency)}</p><p className="mt-5 leading-7 text-slate-300">تسليم رقمي آمن بعد اعتماد الدفع.</p><div className="mt-6"><AddToCart item={{id:item.id,type:'product',title:item.name,price:Number(item.price),currency:item.currency,slug:item.slug}} label="أضف المنتج إلى السلة"/></div><Link href="/cart" className="md-button md-button-ghost mt-3 w-full">عرض السلة</Link><Link href="/refund-policy" className="mt-3 block text-center text-sm text-slate-400 hover:text-white">اطّلع على سياسة الاسترجاع</Link></Card></div></Section></PageShell>}
