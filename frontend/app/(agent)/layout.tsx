import NavBar from "../../components/ui/NavBar";

export default function MainLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="main-layout">
      {children}
      <NavBar />
    </div>
  );
}
