import type { ReactNode } from 'react'
import DashboardAchievementGate from './DashboardAchievementGate'

export default function DashboardTemplate({ children }: { children: ReactNode }) {
  return (
    <>
      {children}
      <DashboardAchievementGate />
    </>
  )
}
