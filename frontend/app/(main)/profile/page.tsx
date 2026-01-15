import { ChevronRight, LogOut, User } from "lucide-react";

export default function Profile(){
    return(
        <div className="min-h-screen min-w-full py-3 px-3">
            <div className="text-center">
                <h1>Profile</h1>
            </div>
            <div className="flex justify-center items-center pb-6">
                <User className="w-45 h-45 bg-(--color-border) rounded-full"/>
            </div>
            <div className="flex flex-col items-center gap-1.5 pb-10">
                <h3>John Doe</h3>
                <h3 className="text-(--color-text)">something@gmail.com</h3>
                <h3 className="text-(--color-text)">+91 9733022122</h3>
            </div>
            <div className="px-2">
                <button className="flex justify-between items-center pb-2 w-full">
                    <h3>Customers</h3>
                    <div className="flex items-center justify-center gap-1">
                        <h3 className="leading-none m-0">8</h3>
                        <ChevronRight className="w-5 h-5" />
                    </div>
                </button>
                <button className="flex justify-between items-center pb-5 w-full">
                    <h3>Change Password</h3>
                    <ChevronRight className="w-5 h-5" />
                </button>
                <button className="flex text-(--color-pending) justify-between items-center w-full">
                    <h3 className="text-(--color-pending)">Logout</h3>
                    <LogOut className="w-5 h-5" />
                </button>
            </div>
        </div>
    );
}