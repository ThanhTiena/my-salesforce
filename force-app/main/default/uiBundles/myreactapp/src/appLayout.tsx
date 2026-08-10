import { Outlet, NavLink, Link, useLocation } from 'react-router';
import { useState } from 'react';
import {
  LayoutDashboard,
  Users,
  FolderKanban,
  FileText,
  Clock,
  Menu,
  X,
  Briefcase,
  Database,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useStore } from '@/lib/store';

interface NavItem {
  to: string;
  label: string;
  icon: typeof LayoutDashboard;
  end?: boolean;
}

const NAV: NavItem[] = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/clients', label: 'Clients', icon: Users },
  { to: '/projects', label: 'Projects', icon: FolderKanban },
  { to: '/invoices', label: 'Invoices', icon: FileText },
  { to: '/time', label: 'Time Tracking', icon: Clock },
  { to: '/salesforce', label: 'Salesforce Data', icon: Database },
];

function NavLinks({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <nav className="flex flex-col gap-1 px-3">
      {NAV.map(item => {
        const Icon = item.icon;
        return (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            onClick={onNavigate}
            data-nav-item
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors',
                isActive
                  ? 'bg-primary text-primary-foreground'
                  : 'text-muted-foreground hover:bg-muted hover:text-foreground'
              )
            }
          >
            <Icon className="size-4" />
            {item.label}
          </NavLink>
        );
      })}
    </nav>
  );
}

function Brand() {
  const { data } = useStore();
  return (
    <Link to="/" className="flex items-center gap-2 px-5 py-4">
      <span className="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground">
        <Briefcase className="size-4.5" />
      </span>
      <span className="text-base font-semibold text-foreground">
        {data.settings.businessName}
      </span>
    </Link>
  );
}

export default function AppLayout() {
  const [open, setOpen] = useState(false);
  const location = useLocation();

  return (
    <div className="min-h-screen bg-muted/30">
      {/* Desktop sidebar */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-60 flex-col border-r border-border bg-background md:flex">
        <Brand />
        <NavLinks />
        <div className="mt-auto px-5 py-4 text-xs text-muted-foreground">
          All your freelance work, in one place.
        </div>
      </aside>

      {/* Mobile top bar */}
      <header className="sticky top-0 z-30 flex items-center justify-between border-b border-border bg-background px-4 py-2.5 md:hidden">
        <Brand />
        <button
          onClick={() => setOpen(true)}
          className="rounded-md p-2 text-muted-foreground hover:bg-muted hover:text-foreground"
          aria-label="Open menu"
        >
          <Menu className="size-5" />
        </button>
      </header>

      {/* Mobile drawer */}
      {open && (
        <div className="fixed inset-0 z-40 md:hidden">
          <div
            className="absolute inset-0 bg-black/40"
            onClick={() => setOpen(false)}
          />
          <div className="absolute inset-y-0 left-0 flex w-64 flex-col bg-background shadow-xl">
            <div className="flex items-center justify-between">
              <Brand />
              <button
                onClick={() => setOpen(false)}
                className="mr-3 rounded-md p-2 text-muted-foreground hover:bg-muted hover:text-foreground"
                aria-label="Close menu"
              >
                <X className="size-5" />
              </button>
            </div>
            <NavLinks onNavigate={() => setOpen(false)} />
          </div>
        </div>
      )}

      {/* Content */}
      <main className="md:pl-60">
        <div
          key={location.pathname}
          className="fops-page mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8"
        >
          <Outlet />
        </div>
      </main>
    </div>
  );
}
