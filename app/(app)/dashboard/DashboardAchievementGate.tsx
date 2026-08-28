'use client'

import { useEffect, useMemo, useState } from 'react'
import { Trophy } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import AchievementCelebration, { type AchievementCelebrationItem } from '@/components/AchievementCelebration'

type Viewer = {
  id: string
  full_name: string
  profile_picture: string | null
  group_color: string | null
}

type MonthlyAward = {
  month_str: string
  category: string
  value: number | null
  detail: string | null
}

const CATEGORY_META: Record<string, { label: string; emoji: string }> = {
  top_earner: { label: 'Top Earner', emoji: '💰' },
  top_scout: { label: 'Top Scout', emoji: '🎯' },
  consistent_earner: { label: 'Consistency Champion', emoji: '⭐' },
  punctuality: { label: 'Punctuality Champion', emoji: '⏰' },
  attendance: { label: 'Attendance Champion', emoji: '📅' },
}

function previousMonthStr() {
  const now = new Date()
  const previous = new Date(now.getFullYear(), now.getMonth() - 1, 1)
  return `${previous.getFullYear()}-${String(previous.getMonth() + 1).padStart(2, '0')}`
}

function monthLabel(monthStr: string) {
  const [year, month] = monthStr.split('-').map(Number)
  if (!year || !month) return monthStr
  return new Intl.DateTimeFormat('en', { month: 'long', year: 'numeric' })
    .format(new Date(year, month - 1, 1))
}

function ordinal(value: number) {
  const mod100 = value % 100
  if (mod100 >= 11 && mod100 <= 13) return `${value}th`
  if (value % 10 === 1) return `${value}st`
  if (value % 10 === 2) return `${value}nd`
  if (value % 10 === 3) return `${value}rd`
  return `${value}th`
}

function valueLabel(category: string, value: number | null) {
  if (value == null) return ''
  if (category === 'top_earner') {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(value)
  }
  if (category === 'top_scout') return `${Math.round(value)} businesses contacted`
  if (category === 'consistent_earner') return `${Math.round(value)} consistency points`
  if (category === 'punctuality') return `${Math.round(value)} min average ahead of the sign-in window`
  if (category === 'attendance') return `${Math.round(value)} days present`
  return String(value)
}

export default function DashboardAchievementGate() {
  const supabase = useMemo(() => createClient(), [])
  const [viewer, setViewer] = useState<Viewer | null>(null)
  const [celebrations, setCelebrations] = useState<AchievementCelebrationItem[]>([])
  const [counts, setCounts] = useState<Record<string, number>>({})

  useEffect(() => {
    let cancelled = false

    async function loadFinalizedAchievements() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user || cancelled) return

      const { data: profile } = await supabase
        .from('profiles')
        .select('id, full_name, profile_picture, color_groups!profiles_color_group_id_fkey(hex_color)')
        .eq('id', user.id)
        .single()

      if (!profile || cancelled) return

      const group = (profile as any).color_groups
      const currentViewer: Viewer = {
        id: profile.id,
        full_name: profile.full_name,
        profile_picture: profile.profile_picture,
        group_color: group?.hex_color ?? null,
      }
      setViewer(currentViewer)

      const completedMonth = previousMonthStr()

      const { error: finalizeError } = await supabase.rpc('finalize_monthly_achievements', {
        p_month_str: completedMonth,
      })
      if (finalizeError) {
        console.warn('Monthly achievement finalization is not available yet:', finalizeError.message)
      }

      const { data: awards, error: awardsError } = await supabase
        .from('monthly_achievements')
        .select('month_str, category, value, detail')
        .eq('user_id', user.id)
        .order('month_str', { ascending: true })

      if (awardsError || cancelled) {
        if (awardsError) console.warn('Could not load monthly achievements:', awardsError.message)
        return
      }

      const typedAwards = (awards ?? []) as MonthlyAward[]
      const runningCounts: Record<string, number> = {}
      const winNumberByKey = new Map<string, number>()

      for (const award of typedAwards) {
        runningCounts[award.category] = (runningCounts[award.category] ?? 0) + 1
        winNumberByKey.set(`${award.category}:${award.month_str}`, runningCounts[award.category])
      }
      setCounts(runningCounts)

      const justWon = typedAwards.filter(award => award.month_str === completedMonth)
      const items: AchievementCelebrationItem[] = justWon.map(award => {
        const meta = CATEGORY_META[award.category] ?? { label: award.category, emoji: '🏆' }
        const winNumber = winNumberByKey.get(`${award.category}:${award.month_str}`) ?? 1
        const metric = valueLabel(award.category, award.value)
        return {
          key: `monthly:${award.category}:${award.month_str}`,
          title: `${meta.label} · ${winNumber}×`,
          detail: `Final ${monthLabel(award.month_str)} winner${metric ? ` · ${metric}` : ''}. This is your ${ordinal(winNumber)} ${meta.label} title.`,
          emoji: meta.emoji,
        }
      })

      setCelebrations(items)
    }

    loadFinalizedAchievements()
    return () => { cancelled = true }
  }, [supabase])

  const countEntries = Object.entries(counts)
    .filter(([category, count]) => count > 0 && CATEGORY_META[category])
    .sort((a, b) => b[1] - a[1])

  if (!viewer) return null

  return (
    <>
      {countEntries.length > 0 && (
        <div className="max-w-7xl mx-auto mt-6">
          <div className="card px-5 py-4">
            <div className="flex items-center gap-2 mb-3">
              <div className="w-9 h-9 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center">
                <Trophy size={18} />
              </div>
              <div>
                <h2 className="text-sm font-bold text-gray-900">My Monthly Achievements</h2>
                <p className="text-xs text-gray-400">Only month-end #1 finishes count as permanent titles.</p>
              </div>
            </div>
            <div className="flex flex-wrap gap-2">
              {countEntries.map(([category, count]) => {
                const meta = CATEGORY_META[category]
                return (
                  <div key={category} className="inline-flex items-center gap-2 rounded-full border border-gray-200 bg-gray-50 px-3 py-1.5 text-sm">
                    <span aria-hidden="true">{meta.emoji}</span>
                    <span className="font-semibold text-gray-700">{meta.label}</span>
                    <span className="font-extrabold text-brand-600">{count}×</span>
                  </div>
                )
              })}
            </div>
          </div>
        </div>
      )}

      {celebrations.length > 0 && (
        <AchievementCelebration
          profileId={viewer.id}
          fullName={viewer.full_name}
          profilePicture={viewer.profile_picture}
          groupColor={viewer.group_color}
          achievements={celebrations}
        />
      )}
    </>
  )
}
