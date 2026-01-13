"use client";

import { Scanner } from "@yudiel/react-qr-scanner";
import { useState } from "react";
import { Image, X } from "lucide-react";


const ScannerPage: React.FC = () => {
    
    const [result, setResult] = useState<string | null>(null);

    return(
        <div className="h-full">

            <div className="relative mx-auto w-58 h-58 rounded-3xl overflow-hidden bg-black">
                <Scanner
                    onScan={(data) => {
                        if (data?.[0]?.rawValue) {
                            setResult(data[0].rawValue);
                        }
                    }}
                    onError={(err) => console.error(err)}
                    classNames={{
                        container: "w-full h-full",
                        video: "w-full h-full object-cover",
                    }}
                />
            </div>

            <div className="pt-3 w-full flex justify-center">
                <h1 className="font-medium text-(--color-primary)">Scan Item QR</h1>
            </div>
            <div className="flex flex-col text-(--color-primary) pb-3 items-center justify-center w-full">
                <h4>Not Working?</h4>
                <h4 className="font-medium">Enter Code Manually</h4>
            </div>
            <div className="flex w-full justify-center">
                <button className="flex gap-1 text-(--color-primary) border border-(--color-primary) p-2 rounded-md">
                    <h4 className="font-light">Scan from Image</h4>
                    <Image/>
                </button>
            </div>
        </div>
    );
}

export default ScannerPage;