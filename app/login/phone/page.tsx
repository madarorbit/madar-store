import PageShell from'@/components/ui/PageShell';import{PageHero,Section}from'@/components/ui/Section';import PhoneLoginForm from'./form';
export default function Page(){return <PageShell><PageHero eyebrow="دخول آمن" title="تسجيل الدخول عبر واتساب" description="استلم رمز تحقق على رقم واتساب وأدخله لإكمال الدخول دون كلمة مرور."/><Section><PhoneLoginForm/></Section></PageShell>}
