import { Spinner } from "./spinner";

interface PageLoadingProps {
  text?: string;
}

export function PageLoading({ text = "" }: PageLoadingProps) {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen gap-2">
      <Spinner className="h-8 w-8" />
      {text && <p className="text-lg">{text}</p>}
    </div>
  );
}
