import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { LogIn } from "lucide-react";

export default function Login() {
  return (
    <div className="flex min-h-screen min-w-full py-6 px-6 justify-center items-center">
      <div className="flex flex-col w-full gap-16">
        <h2 className="flex text-4xl w-full justify-center text-(--color-primary)">
          Login
        </h2>
        <div className="flex flex-col gap-6">
          <Field>
            <FieldLabel>Email</FieldLabel>
            <Input type="text" placeholder="example@gmail.com"></Input>
          </Field>
          <Field>
            <FieldLabel>Password</FieldLabel>
            <Input type="password" placeholder="*****"></Input>
          </Field>

          <div className="flex justify-center gap-2.5">
            <StockFlowButton variant="filled" text="Login" icon={<LogIn />} />
          </div>
        </div>
      </div>
    </div>
  );
}
