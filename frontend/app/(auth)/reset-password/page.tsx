import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { X, Check } from "lucide-react";

export default function ResetPassword(){
    return(
        <div className="flex flex-col justify-center">
            <h2 className="text-(--color-primary) text-[20px] text-center">Reset Password</h2>
            <div className="absolute inset-0 p-5 flex justify-center flex-col gap-6">
                <Field>
                    <FieldLabel>Current Password</FieldLabel>
                    <Input type="password" placeholder="********"></Input>
                </Field>
                <Field>
                    <FieldLabel>New Password</FieldLabel>
                    <Input type="password" placeholder="********"></Input>
                </Field>
                <Field>
                    <FieldLabel>Re-enter new Password</FieldLabel>
                    <Input type="password" placeholder="********"></Input>
                </Field>
            </div>
            <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full">
                <div className="px-8 py-4 flex items-center justify-center gap-2 ">
                    <StockFlowButton text="Back" variant="outline" icon={<X/>}/>
                    <StockFlowButton text="Reset Password" icon={<Check/>}/>
                </div>
            </div>
        </div>
    );
}

