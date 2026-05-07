import PushNotificationInit from "@/lib/pushInit";

export default function NoLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="auth-layout">
      <PushNotificationInit />
      {children}
    </div>
  );
}
