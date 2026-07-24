import {Notice} from '@/components/ui/Enterprise';

export default function ActionFeedback({success,error}:{success?:string;error?:string}){
 if(!success&&!error)return null;
 return <div className="mb-5"><Notice title={error?'تعذر إكمال العملية':'تمت العملية بنجاح'} variant={error?'danger':'success'}>{error||success}</Notice></div>;
}
