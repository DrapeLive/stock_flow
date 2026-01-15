import { customer } from "@/app/dummy_data/customers";
import { ArrowRight, X } from "lucide-react";


const ListCustomer: React.FC = () => {
    return(
        <div className="py-4 px-5 min-h-screen">
            <div className="pb-2">
                <h4 className="font-medium">Select Customer</h4>
            </div>
            <div className="border border-(--color-border) rounded-md">
                {
                    customer.map((item, index) => (
                        <button key={index} className="flex w-full justify-between items-center p-2.5 border-b border-(--color-border)">
                            <h4>{item.name}</h4>
                            <ArrowRight className="font-extrabold w-5 h-5"/>
                        </button>
                    ))
                }
            </div>
        </div>
    );
}

export default ListCustomer;