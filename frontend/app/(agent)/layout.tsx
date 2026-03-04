import NavBar from "../../components/ui/NavBar";
import AgentProfileButton from "@/components/ui/custom/agentProfileButton";

export default function MainLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="main-layout pb-32">
      <AgentProfileButton />
      {children}
      <NavBar />
    </div>
  );
}
