import { Input } from "@/components/ui/input";
import { Filter, Search } from "lucide-react";

export default function History(){
    return(
        <div className="min-h-screen min-w-full py-3 px-3">
            <div className='relative'>
                <div className='text-muted-foreground pointer-events-none absolute inset-y-0 left-0 flex items-center justify-center pl-3 peer-disabled:opacity-50'>
                    <Search className='size-4' />
                </div>
                <Input type='text' placeholder='search orders..' className='peer pl-9 py-6' />
            </div>
            <div className="pt-3 flex justify-between">
                <div className="flex gap-1 items-center">
                    <p>Remaining Order</p>
                    <div className="bg-(--color-border) rounded-full py-0.5 px-2">
                        <p className="font-bold">40</p>
                    </div>
                </div>
                <div className="p-0.5 rounded-[3px] border border-(--color-border)">
                    <Filter className="text-(--color-border) w-2.5 h-2.5"/>
                </div>
            </div>
        </div>
    );
}