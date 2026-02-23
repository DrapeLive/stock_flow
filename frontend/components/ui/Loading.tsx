import { Spinner } from "./spinner";

export function PageLoading() {
  return (
    <div className="flex items-center justify-center min-h-screen">
      <Spinner className="h-8 w-8" />
    </div>
  );
}
