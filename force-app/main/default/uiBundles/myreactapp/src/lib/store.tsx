import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import type {
  Client,
  Invoice,
  Project,
  TimeEntry,
  WorkspaceData,
} from './types';
import { seedData } from './seed';

const STORAGE_KEY = 'freelancehub:v1';

/** Generate a reasonably unique id, preferring the platform UUID generator. */
function newId(): string {
  const c = (globalThis as { crypto?: Crypto }).crypto;
  if (c && typeof c.randomUUID === 'function') return c.randomUUID();
  return `id-${Date.now().toString(36)}-${Math.floor(
    Math.random() * 1e9
  ).toString(36)}`;
}

function loadData(): WorkspaceData {
  try {
    const raw =
      typeof localStorage !== 'undefined'
        ? localStorage.getItem(STORAGE_KEY)
        : null;
    if (raw) {
      const parsed = JSON.parse(raw) as WorkspaceData;
      // Basic shape guard so a partial/old payload can't crash the app.
      if (parsed && Array.isArray(parsed.clients)) {
        return {
          clients: parsed.clients ?? [],
          projects: parsed.projects ?? [],
          invoices: parsed.invoices ?? [],
          timeEntries: parsed.timeEntries ?? [],
          settings: parsed.settings ?? seedData().settings,
        };
      }
    }
  } catch (err) {
    console.error('Failed to load FreelanceHub data, using seed', err);
  }
  return seedData();
}

interface StoreContextValue {
  data: WorkspaceData;

  // Clients
  addClient: (input: Omit<Client, 'id' | 'createdAt'>) => Client;
  updateClient: (id: string, patch: Partial<Client>) => void;
  deleteClient: (id: string) => void;

  // Projects
  addProject: (input: Omit<Project, 'id' | 'createdAt'>) => Project;
  updateProject: (id: string, patch: Partial<Project>) => void;
  deleteProject: (id: string) => void;

  // Invoices
  addInvoice: (input: Omit<Invoice, 'id' | 'createdAt'>) => Invoice;
  updateInvoice: (id: string, patch: Partial<Invoice>) => void;
  deleteInvoice: (id: string) => void;

  // Time entries
  addTimeEntry: (input: Omit<TimeEntry, 'id' | 'createdAt'>) => TimeEntry;
  updateTimeEntry: (id: string, patch: Partial<TimeEntry>) => void;
  deleteTimeEntry: (id: string) => void;

  updateSettings: (patch: Partial<WorkspaceData['settings']>) => void;
  resetToSeed: () => void;

  /** Next sequential invoice number, e.g. "INV-0007". */
  nextInvoiceNumber: () => string;
}

const StoreContext = createContext<StoreContextValue | null>(null);

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const [data, setData] = useState<WorkspaceData>(loadData);

  // Persist on every change. Cheap for a single-user local dataset.
  useEffect(() => {
    try {
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
      }
    } catch (err) {
      console.error('Failed to persist FreelanceHub data', err);
    }
  }, [data]);

  const addClient = useCallback((input: Omit<Client, 'id' | 'createdAt'>) => {
    const client: Client = {
      ...input,
      id: newId(),
      createdAt: new Date().toISOString(),
    };
    setData(d => ({ ...d, clients: [client, ...d.clients] }));
    return client;
  }, []);

  const updateClient = useCallback((id: string, patch: Partial<Client>) => {
    setData(d => ({
      ...d,
      clients: d.clients.map(c => (c.id === id ? { ...c, ...patch } : c)),
    }));
  }, []);

  const deleteClient = useCallback((id: string) => {
    setData(d => {
      const projectIds = new Set(
        d.projects.filter(p => p.clientId === id).map(p => p.id)
      );
      return {
        ...d,
        clients: d.clients.filter(c => c.id !== id),
        projects: d.projects.filter(p => p.clientId !== id),
        invoices: d.invoices.filter(i => i.clientId !== id),
        timeEntries: d.timeEntries.filter(t => !projectIds.has(t.projectId)),
      };
    });
  }, []);

  const addProject = useCallback((input: Omit<Project, 'id' | 'createdAt'>) => {
    const project: Project = {
      ...input,
      id: newId(),
      createdAt: new Date().toISOString(),
    };
    setData(d => ({ ...d, projects: [project, ...d.projects] }));
    return project;
  }, []);

  const updateProject = useCallback((id: string, patch: Partial<Project>) => {
    setData(d => ({
      ...d,
      projects: d.projects.map(p => (p.id === id ? { ...p, ...patch } : p)),
    }));
  }, []);

  const deleteProject = useCallback((id: string) => {
    setData(d => ({
      ...d,
      projects: d.projects.filter(p => p.id !== id),
      timeEntries: d.timeEntries.filter(t => t.projectId !== id),
      invoices: d.invoices.map(i =>
        i.projectId === id ? { ...i, projectId: undefined } : i
      ),
    }));
  }, []);

  const addInvoice = useCallback((input: Omit<Invoice, 'id' | 'createdAt'>) => {
    const invoice: Invoice = {
      ...input,
      id: newId(),
      createdAt: new Date().toISOString(),
    };
    setData(d => ({ ...d, invoices: [invoice, ...d.invoices] }));
    return invoice;
  }, []);

  const updateInvoice = useCallback((id: string, patch: Partial<Invoice>) => {
    setData(d => ({
      ...d,
      invoices: d.invoices.map(i => (i.id === id ? { ...i, ...patch } : i)),
    }));
  }, []);

  const deleteInvoice = useCallback((id: string) => {
    setData(d => ({ ...d, invoices: d.invoices.filter(i => i.id !== id) }));
  }, []);

  const addTimeEntry = useCallback(
    (input: Omit<TimeEntry, 'id' | 'createdAt'>) => {
      const entry: TimeEntry = {
        ...input,
        id: newId(),
        createdAt: new Date().toISOString(),
      };
      setData(d => ({ ...d, timeEntries: [entry, ...d.timeEntries] }));
      return entry;
    },
    []
  );

  const updateTimeEntry = useCallback(
    (id: string, patch: Partial<TimeEntry>) => {
      setData(d => ({
        ...d,
        timeEntries: d.timeEntries.map(t =>
          t.id === id ? { ...t, ...patch } : t
        ),
      }));
    },
    []
  );

  const deleteTimeEntry = useCallback((id: string) => {
    setData(d => ({
      ...d,
      timeEntries: d.timeEntries.filter(t => t.id !== id),
    }));
  }, []);

  const updateSettings = useCallback(
    (patch: Partial<WorkspaceData['settings']>) => {
      setData(d => ({ ...d, settings: { ...d.settings, ...patch } }));
    },
    []
  );

  const resetToSeed = useCallback(() => setData(seedData()), []);

  const nextInvoiceNumber = useCallback(() => {
    const max = data.invoices.reduce((acc, inv) => {
      const m = /(\d+)\s*$/.exec(inv.number);
      return m ? Math.max(acc, parseInt(m[1], 10)) : acc;
    }, 0);
    return `INV-${String(max + 1).padStart(4, '0')}`;
  }, [data.invoices]);

  const value = useMemo<StoreContextValue>(
    () => ({
      data,
      addClient,
      updateClient,
      deleteClient,
      addProject,
      updateProject,
      deleteProject,
      addInvoice,
      updateInvoice,
      deleteInvoice,
      addTimeEntry,
      updateTimeEntry,
      deleteTimeEntry,
      updateSettings,
      resetToSeed,
      nextInvoiceNumber,
    }),
    [
      data,
      addClient,
      updateClient,
      deleteClient,
      addProject,
      updateProject,
      deleteProject,
      addInvoice,
      updateInvoice,
      deleteInvoice,
      addTimeEntry,
      updateTimeEntry,
      deleteTimeEntry,
      updateSettings,
      resetToSeed,
      nextInvoiceNumber,
    ]
  );

  return (
    <StoreContext.Provider value={value}>{children}</StoreContext.Provider>
  );
}

export function useStore(): StoreContextValue {
  const ctx = useContext(StoreContext);
  if (!ctx) {
    throw new Error('useStore must be used within a StoreProvider');
  }
  return ctx;
}

/** Convenience lookups derived from the store. */
export function useClientMap(): Map<string, Client> {
  const { data } = useStore();
  return useMemo(
    () => new Map(data.clients.map(c => [c.id, c])),
    [data.clients]
  );
}

export function useProjectMap(): Map<string, Project> {
  const { data } = useStore();
  return useMemo(
    () => new Map(data.projects.map(p => [p.id, p])),
    [data.projects]
  );
}
