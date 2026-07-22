export const orderStatus:Record<string,string>={awaiting_payment:'بانتظار الدفع',payment_review:'قيد مراجعة الدفع',paid:'مدفوع',processing:'قيد التنفيذ',completed:'مكتمل',cancelled:'ملغي',rejected:'مرفوض'};
export const paymentStatus:Record<string,string>={unpaid:'غير مدفوع',under_review:'قيد المراجعة',approved:'معتمد',rejected:'مرفوض',refunded:'مسترجع'};
export function money(value:number|string,currency='SAR'){return `${Number(value).toLocaleString('ar-SA',{minimumFractionDigits:2,maximumFractionDigits:2})} ${currency}`}
