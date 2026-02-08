"use client";

interface SkeletonProps {
  className?: string;
  style?: React.CSSProperties;
}

export function Skeleton({ className = "", style }: SkeletonProps) {
  return <div className={`skeleton ${className}`} style={style} />;
}

export function SkeletonCard() {
  return (
    <div className="rounded-xl border border-[#2f2f2f] bg-[#0A0A0A] px-5 py-4">
      <Skeleton className="mb-3 h-3 w-24" />
      <Skeleton className="h-7 w-32" />
    </div>
  );
}

export function SkeletonChart({ height = 220 }: { height?: number }) {
  return (
    <div className="rounded-xl border border-[#2f2f2f] bg-[#0A0A0A]">
      <div className="px-6 py-4">
        <Skeleton className="mb-2 h-4 w-40" />
        <Skeleton className="h-3 w-56" />
      </div>
      <div className="border-t border-[#2f2f2f] px-6 py-5">
        <Skeleton className="w-full" style={{ height }} />
      </div>
    </div>
  );
}

export function SkeletonTable({ rows = 3 }: { rows?: number }) {
  return (
    <div className="rounded-xl border border-[#2f2f2f] bg-[#0A0A0A]">
      <div className="px-6 py-4">
        <Skeleton className="h-4 w-48" />
      </div>
      <div className="border-t border-[#2f2f2f]">
        {Array.from({ length: rows }).map((_, i) => (
          <div
            key={i}
            className="flex items-center gap-6 border-b border-[#2f2f2f] px-6 py-3 last:border-b-0"
          >
            <Skeleton className="h-3 w-28" />
            <Skeleton className="h-3 w-20" />
            <Skeleton className="ml-auto h-3 w-16" />
          </div>
        ))}
      </div>
    </div>
  );
}
