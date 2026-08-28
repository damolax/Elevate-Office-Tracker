'use client'

import { useEffect, useMemo, useState } from 'react'
import { Trophy, X, Star } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

export type AchievementCelebrationItem = {
  key: string
  title: string
  detail: string
  emoji: string
}

type Props = {
  profileId: string
  fullName: string
  profilePicture?: string | null
  groupColor?: string | null
  achievements: AchievementCelebrationItem[]
}

const STORAGE_KEY = 'elevate_seen_achievement_celebrations'
const META_KEY = 'elevate_achievement_celebrations'
const MAX_SAVED_KEYS = 120

const CONFETTI = Array.from({ length: 34 }, (_, i) => ({
  left: `${(i * 29 + 7) % 100}%`,
  delay: `${(i % 9) * 70}ms`,
  duration: `${1250 + (i % 6) * 140}ms`,
  rotate: `${(i * 47) % 360}deg`,
}))

function readLocalSeen(): string[] {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY)
    const parsed = raw ? JSON.parse(raw) : []
    return Array.isArray(parsed) ? parsed.filter((v): v is string => typeof v === 'string') : []
  } catch {
    return []
  }
}

function writeLocalSeen(keys: string[]) {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(keys.slice(-MAX_SAVED_KEYS)))
  } catch {
    // Local storage is only a fallback; Supabase metadata remains the primary record.
  }
}

export default function AchievementCelebration({
  profileId,
  fullName,
  profilePicture,
  groupColor,
  achievements,
}: Props) {
  const supabase = useMemo(() => createClient(), [])
  const [visible, setVisible] = useState<AchievementCelebrationItem[]>([])

  useEffect(() => {
    let cancelled = false

    async function checkCelebrations() {
      if (!achievements.length) return

      const localSeen = readLocalSeen()
      const { data } = await supabase.auth.getUser()
      if (cancelled || !data.user || data.user.id !== profileId) return

      const metadataSeen = Array.isArray(data.user.user_metadata?.[META_KEY])
        ? data.user.user_metadata[META_KEY].filter((v: unknown): v is string => typeof v === 'string')
        : []
      const seen = new Set([...metadataSeen, ...localSeen])
      const unseen = achievements.filter(item => !seen.has(item.key))

      if (!unseen.length) return

      const merged = [...seen, ...unseen.map(item => item.key)].slice(-MAX_SAVED_KEYS)
      writeLocalSeen(merged)
      setVisible(unseen)

      const { error } = await supabase.auth.updateUser({
        data: { [META_KEY]: merged },
      })
      if (error) console.warn('Could not persist achievement celebration metadata:', error.message)
    }

    checkCelebrations()
    return () => { cancelled = true }
  }, [achievements, profileId, supabase])

  useEffect(() => {
    if (!visible.length) return
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setVisible([])
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [visible.length])

  if (!visible.length) return null

  const firstName = fullName.trim().split(/\s+/)[0] || 'Champion'
  const multiple = visible.length > 1

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-gray-950/55 backdrop-blur-sm" role="presentation">
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="achievement-title"
        className="relative w-full max-w-lg overflow-hidden rounded-3xl bg-white shadow-2xl border border-amber-100"
      >
        <button
          type="button"
          onClick={() => setVisible([])}
          aria-label="Close celebration"
          className="absolute right-4 top-4 z-20 w-10 h-10 rounded-full bg-white/90 border border-gray-200 text-gray-500 flex items-center justify-center hover:text-gray-900 transition-colors"
        >
          <X size={18} />
        </button>

        <div className="absolute inset-0 pointer-events-none overflow-hidden" aria-hidden="true">
          {CONFETTI.map((piece, i) => (
            <span
              key={i}
              className={`achievement-confetti ${i % 4 === 0 ? 'bg-amber-400' : i % 4 === 1 ? 'bg-brand-500' : i % 4 === 2 ? 'bg-emerald-400' : 'bg-pink-400'}`}
              style={{
                left: piece.left,
                animationDelay: piece.delay,
                animationDuration: piece.duration,
                transform: `rotate(${piece.rotate})`,
              }}
            />
          ))}
        </div>

        <div className="relative px-6 sm:px-8 pt-9 pb-7 text-center">
          <div className="mx-auto w-20 h-20 rounded-full bg-amber-50 border-4 border-white shadow-lg flex items-center justify-center relative">
            {profilePicture ? (
              <img src={profilePicture} alt={fullName} className="w-full h-full rounded-full object-cover" />
            ) : (
              <div
                className="w-full h-full rounded-full text-white flex items-center justify-center text-2xl font-extrabold"
                style={{ backgroundColor: groupColor ?? '#4f46e5' }}
              >
                {firstName.slice(0, 1).toUpperCase()}
              </div>
            )}
            <div className="absolute -right-2 -bottom-1 w-9 h-9 rounded-full bg-amber-400 text-white border-4 border-white flex items-center justify-center">
              <Trophy size={17} />
            </div>
          </div>

          <div className="mt-5 inline-flex items-center gap-1.5 rounded-full bg-amber-50 px-3 py-1 text-xs font-bold uppercase tracking-wider text-amber-700">
            <Star size={13} fill="currentColor" /> Month-end achievement
          </div>

          <h2 id="achievement-title" className="mt-3 text-2xl sm:text-3xl font-extrabold text-gray-900">
            Congratulations, {firstName}! 🎉
          </h2>
          <p className="mt-2 text-sm text-gray-500">
            {multiple
              ? `You finished the month as the final #1 in ${visible.length} achievement categories.`
              : 'You finished the month as the final #1 in an achievement category.'}
          </p>

          <div className="mt-6 space-y-2 text-left">
            {visible.map(item => (
              <div key={item.key} className="flex items-start gap-3 rounded-2xl border border-gray-100 bg-gray-50 px-4 py-3">
                <div className="text-2xl leading-none mt-0.5" aria-hidden="true">{item.emoji}</div>
                <div className="min-w-0">
                  <div className="font-bold text-gray-900">{item.title}</div>
                  <div className="text-sm text-gray-500 mt-0.5">{item.detail}</div>
                </div>
              </div>
            ))}
          </div>

          <p className="mt-5 text-sm font-semibold text-gray-700">The title is now part of your permanent Elevate achievement record. 🏆</p>

          <button
            type="button"
            onClick={() => setVisible([])}
            className="mt-5 w-full rounded-xl bg-brand-600 px-4 py-3 text-sm font-bold text-white hover:bg-brand-700 active:scale-[0.99] transition-all"
          >
            Celebrate &amp; Continue
          </button>
        </div>

        <style jsx>{`
          .achievement-confetti {
            position: absolute;
            top: -18px;
            width: 9px;
            height: 16px;
            border-radius: 2px;
            opacity: 0;
            animation-name: achievement-fall;
            animation-timing-function: cubic-bezier(.2,.7,.3,1);
            animation-fill-mode: forwards;
          }
          @keyframes achievement-fall {
            0% { opacity: 0; translate: 0 -12px; }
            12% { opacity: 1; }
            100% { opacity: 0; translate: var(--drift, 22px) 560px; rotate: 540deg; }
          }
          @media (prefers-reduced-motion: reduce) {
            .achievement-confetti { display: none; }
          }
        `}</style>
      </div>
    </div>
  )
}
