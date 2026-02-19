"use client";

import { useEffect, useRef } from "react";
import { useParams, useRouter } from "next/navigation";
import QRCode from "react-qr-code";

const QRPage: React.FC = () => {
  const params = useParams();
  const id = params.id as string;

  const router = useRouter();
  const hasPrinted = useRef(false);

  useEffect(() => {
    if (!hasPrinted.current) {
      window.print();
      router.back();
      hasPrinted.current = true;
    }
  }, [router]);

  return (
    <div
      style={{
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        height: "100vh",
      }}
    >
      <QRCode value={id} size={256} />
    </div>
  );
};

export default QRPage;
