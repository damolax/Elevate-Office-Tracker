'use client'

import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import AchievementCelebration, { type AchievementCelebrationItem } from '@/components/AchievementCelebration'

type Viewer = {
  id: string
  full_name: string
  member_id: string | null
  profile_picture: string | null
  group_color: string | null
}

const LEADERBOARDS = [
  { title: 'Top Scouts Today', id: 'top-scouts', label: 'Top Scout Today', emoji: '🎯', scope: 'day' },
  { title: 'Top 20 Earners', id: 'top-earner', label: 'Top Earner', emoji: '💰', scope: 'range' },
  { title: 'Top 20 Most Consistent Earners', id: 'consistent-earner', label: 'Most Consistent Earner', emoji: '⭐', scope: 'range' },
  { title: 'Top 20 Punctuality', id: 'punctuality', label: 'Punctuality Champion', emoji: '⏰', scope: 'range' },
  { title: 'Most Consistent Attendance', id: 'attendance', label: 'Attendance Champion', emoji: '📅', scope: 'range' },
] as const

function localDateKey() {
  const now = new Date()
  const y = now.getFullYear()
  const m = String(now.getMonth() + 1).padStart(2, '0')
  const d = String(now.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

function rangePeriodKey(range: string) {
  const now = new Date()
  const y = now.getFullYear()
  const m = String(now.getMonth() + 1).padStart(2, '0')
  const weekStart = new Date(now)
  const day = (now.getDay() + 6) % 7
  weekStart.setDate(now.getDate() - day)
  const wy = weekStart.getFullYear()
  const wm = String(weekStart.getMonth() + 1).padStart(2, '0')
  const wd = String(weekStart.getDate()).padStart(2, '0')

  if (range === 'this_week') return `week-${wy}-${wm}-${wd}`
  if (range === 'this_month') return `month-${y}-${m}`
  return `${range}-${localDateKey()}`
}

function normalize(value: string) {
  return value.replace(/\s+/g, ' ').trim().toLowerCase()
}

function findCardByHeading(titlePart: string): HTMLElement | null {
  const headings = Array.from(document.querySelectorAll('h1,h2,h3')) as HTMLElement[]
  const heading = headings.find(node => normalize(node.textContent ?? '').includes(normalize(titlePart)))
  return heading?.closest('.card') as HTMLElement | null
}

function firstLeaderboardEntry(card: HTMLElement): HTMLElement | null {
  const tableRow = card.querySelector('tbody tr') as HTMLElement | null
  if (tableRow) return tableRow

  // The Top Scouts card is a compact stacked list rather than a table.
  const list = card.querySelector('.space-y-3')
  if (list?.firstElementChild) return list.firstElementChild as HTMLElement

  return null
}

function isViewer(entry: HTMLElement, viewer: Viewer) {
  const text = normalize(entry.textContent ?? '')
  if (text.includes('(you)')) return true
  if (viewer.member_id && text.includes(normalize(viewer.member_id))) return true
  if (viewer.full_name && text.includes(normalize(viewer.full_name))) return true
  return false
}

function entryDetail(entry: HTMLElement, fallback: string) {
  const text = (entry.textContent ?? '').replace(/\s+/g, ' ').trim()
  if (!text) return fallback
  return text.replace(/\(You\)/gi, '').trim().slice(0, 130)
}

export default function DashboardAchievementGate() {
  const supabase = useMemo(() => createClient(), [])
  const searchParams = useSearchParams()
  const range = searchParams.get('range') ?? 'this_month'
  const [viewer, setViewer] = useState<Viewer | null>(null)
  const [achievements, setAchievements] = useState<AchievementCelebrationItem[]>([])

  useEffect(() => {
    let cancelled = false

    async function loadViewer() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user || cancelled) return

      const { data } = await supabase
        .from('profiles')
        .select('id, full_name, member_id, profile_picture, color_groups!profiles_color_group_id_fkey(hex_color)')
        .eq('id', user.id)
        .single()

      if (!data || cancelled) return
      const group = (data as any).color_groups
      setViewer({
        id: data.id,
        full_name: data.full_name,
        member_id: data.member_id,
        profile_picture: data.profile_picture,
        group_color: group?.hex_color ?? null,
      })
    }

    loadViewer()
    return () => { cancelled = true }
  }, [supabase])

  useEffect(() => {
    if (!viewer) return

    let timer: ReturnType<typeof setTimeout> | null = null
    let attempts = 0

    const inspect = () => {
      attempts += 1
      const found: AchievementCelebrationItem[] = []
      let cardsFound = 0

      for (const board of LEADERBOARDS) {
        const card = findCardByHeading(board.title)
        if (!card) continue
        cardsFound += 1

        const first = firstLeaderboardEntry(card)
        if (!first || !isViewer(first, viewer)) continue

        const period = board.scope === 'day' ? localDateKey() : rangePeriodKey(range)
        found.push({
          key: `${board.id}:${period}`,
          title: board.label,
          detail: entryDetail(first, `You are currently #1 in ${board.label.toLowerCase()}.`),
          emoji: board.emoji,
        })
      }

      setAchievements(found)

      // Dashboard data is server-rendered, but allow a few retries for transitions/navigation.
      if (cardsFound < LEADERBOARDS.length && attempts < 8) {
        timer = setTimeout(inspect, 250)
      }
    }

    timer = setTimeout(inspect, 80)
    return () => { if (timer) clearTimeout(timer) }
  }, [viewer, range])

  if (!viewer || !achievements.length) return null

  return (
    <AchievementCelebration
      profileId={viewer.id}
      fullName={viewer.full_name}
      profilePicture={viewer.profile_picture}
      groupColor={viewer.group_color}
      achievements={achievements}
    />
  )
}
