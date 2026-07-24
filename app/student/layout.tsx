import Image from 'next/image';
import Link from 'next/link';
import type {ReactNode} from 'react';
import Navbar from '@/components/layout/Navbar';
import Footer from '@/components/layout/Footer';
import {siteConfig} from '@/src/config/site';
import {Icon} from '@/components/ui/Icons';

export default function StudentLayout({children}:{children:ReactNode}){return <><Navbar/><div className="md-shell"><header className="border-b border-white/10 bg-[#0b1020]/90 md-no-print"><div className="md-container flex min-h-16 flex-wrap items-center justify-between gap-3 py-3"><div className="flex items-center gap-3"><span className="grid h-10 w-10 place-items-center rounded-xl bg-emerald-300/10 text-emerald-200">🎓</span><div><p className="text-xs font-bold text-emerald-300">مَدار للتعليم</p><strong>مساحة الطالب الجامعي</strong></div></div><div className="flex items-center gap-2"><a href="#ai" className="md-orby-chip"><Image src={siteConfig.assets.orby} alt="صورة أوربي" width={32} height={32} unoptimized className="md-orby-avatar"/><span>مساعد أوربي</span></a><Link href="/account" className="md-button md-button-secondary md-button-sm"><Icon name="user"/>حسابي</Link></div></div></header>{children}</div><Footer/></>}
