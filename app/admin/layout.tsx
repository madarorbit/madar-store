import {requireAdmin} from '@/src/lib/auth';
import EnterpriseAdminShell from '@/components/admin/EnterpriseAdminShell';

export default async function AdminLayout({children}:{children:React.ReactNode}){
 const profile=await requireAdmin();
 return <EnterpriseAdminShell displayName={profile.full_name||'حساب الإدارة'} isFounder={profile.role==='SUPER_ADMIN'}>{children}</EnterpriseAdminShell>;
}
