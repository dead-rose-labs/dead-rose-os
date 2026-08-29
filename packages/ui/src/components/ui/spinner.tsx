import { LoaderCircle } from "lucide-react";

export function Spinner() {
  return (
    <LoaderCircle data-icon="inline-start" className="animate-spin motion-reduce:animate-none" aria-hidden="true" />
  );
}
