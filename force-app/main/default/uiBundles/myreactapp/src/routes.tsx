import type { RouteObject } from 'react-router';
import AppLayout from '@/appLayout';
import Dashboard from './pages/Dashboard';
import Clients from './pages/Clients';
import Projects from './pages/Projects';
import Invoices from './pages/Invoices';
import TimeTracking from './pages/TimeTracking';
import NotFound from './pages/NotFound';

export const routes: RouteObject[] = [
  {
    path: '/',
    element: <AppLayout />,
    children: [
      {
        index: true,
        element: <Dashboard />,
        handle: { showInNavigation: true, label: 'Dashboard' },
      },
      {
        path: 'clients',
        element: <Clients />,
        handle: { showInNavigation: true, label: 'Clients' },
      },
      {
        path: 'projects',
        element: <Projects />,
        handle: { showInNavigation: true, label: 'Projects' },
      },
      {
        path: 'invoices',
        element: <Invoices />,
        handle: { showInNavigation: true, label: 'Invoices' },
      },
      {
        path: 'time',
        element: <TimeTracking />,
        handle: { showInNavigation: true, label: 'Time Tracking' },
      },
      {
        path: '*',
        element: <NotFound />,
      },
    ],
  },
];
