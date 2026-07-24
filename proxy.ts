import {NextRequest,NextResponse} from 'next/server';

const cookieOptions=(maxAge:number)=>({httpOnly:true,secure:process.env.NODE_ENV==='production',sameSite:'lax' as const,path:'/',maxAge});
const maintenanceAllowed=['/maintenance','/login','/auth','/admin','/api/health','/_next','/favicon','/robots.txt','/sitemap.xml'];
const sessionProtected=['/admin','/account','/dashboard','/onboarding','/student','/workspace','/workspace-payment'];

function expiresSoon(token:string){
 try{const payload=JSON.parse(Buffer.from(token.split('.')[1],'base64url').toString()) as {exp?:number};return !payload.exp||payload.exp<=Math.floor(Date.now()/1000)+60}catch{return true}
}

async function maintenanceRedirect(request:NextRequest){
 const path=request.nextUrl.pathname;if(maintenanceAllowed.some(prefix=>path.startsWith(prefix))||/\.[a-z0-9]+$/i.test(path))return null;
 const base=(process.env.NEXT_PUBLIC_SUPABASE_URL||'https://rybzdpduwgnsjofolini.supabase.co').replace(/\/$/,''),key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY||'sb_publishable_L4P1zdLREZ_9KR3Bew8zkQ_81_h9iyx';
 try{const response=await fetch(`${base}/rest/v1/platform_settings?id=eq.1&select=maintenance_mode`,{headers:{apikey:key,Authorization:`Bearer ${key}`},cache:'no-store'}),settings=await response.json();if(response.ok&&settings?.[0]?.maintenance_mode){const target=request.nextUrl.clone();target.pathname='/maintenance';target.search='';return NextResponse.redirect(target)}}catch{}
 return null;
}

export async function proxy(request:NextRequest){
 const maintenance=await maintenanceRedirect(request);if(maintenance)return maintenance;
 if(!sessionProtected.some(prefix=>request.nextUrl.pathname.startsWith(prefix)))return NextResponse.next();
 const access=request.cookies.get('madar-access-token')?.value,refresh=request.cookies.get('madar-refresh-token')?.value;
 if(!refresh||(access&&!expiresSoon(access)))return NextResponse.next();
 const base=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;if(!base||!key)return NextResponse.next();
 const response=await fetch(`${base}/auth/v1/token?grant_type=refresh_token`,{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:refresh})}).catch(()=>null),result=NextResponse.next();
 if(!response?.ok){result.cookies.set('madar-access-token','',cookieOptions(0));result.cookies.set('madar-refresh-token','',cookieOptions(0));return result}
 const session=await response.json() as {access_token:string;refresh_token:string;expires_in:number};result.cookies.set('madar-access-token',session.access_token,cookieOptions(session.expires_in||3600));result.cookies.set('madar-refresh-token',session.refresh_token,cookieOptions(60*60*24*30));return result;
}

export const config={matcher:['/((?!_next/static|_next/image).*)']};
