'use client'

import { useState, useEffect, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Profile, CommunityPost } from '@/lib/types'
import { formatDate, getStatusLabel } from '@/lib/utils'
import { Send, Trash2, ImageIcon } from 'lucide-react'
import { format, parseISO } from 'date-fns'

export default function CommunityClient({
  profile, initialPosts, isAdmin,
}: {
  profile: Profile
  initialPosts: CommunityPost[]
  isAdmin: boolean
}) {
  const [posts, setPosts] = useState(initialPosts)
  const [content, setContent] = useState('')
  const [posting, setPosting] = useState(false)
  const [msg, setMsg] = useState<string | null>(null)
  const bottomRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const supabase = createClient()
    const channel = supabase
      .channel('community_posts')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'community_posts',
      }, async (payload) => {
        const { data } = await supabase
          .from('community_posts')
          .select('*, profiles(id, full_name, member_id, profile_picture, status, color_groups(name, hex_color))')
          .eq('id', payload.new.id)
          .single()
        if (data) setPosts(prev => [data as any, ...prev])
      })
      .on('postgres_changes', {
        event: 'DELETE',
        schema: 'public',
        table: 'community_posts',
      }, (payload) => {
        setPosts(prev => prev.filter(p => p.id !== payload.old.id))
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [])

  async function post() {
    if (!content.trim()) return
    setPosting(true)
    const supabase = createClient()
    const { error } = await supabase.from('community_posts').insert({
      user_id: profile.id,
      content: content.trim(),
    })
    if (error) setMsg(error.message)
    else setContent('')
    setPosting(false)
  }

  async function deletePost(id: string) {
    const supabase = createClient()
    await supabase.from('community_posts').delete().eq('id', id)
  }

  return (
    <div className="flex flex-col h-[calc(100vh-120px)] max-w-3xl mx-auto">
      {/* Header */}
      <div className="card p-4 mb-4 flex-shrink-0">
        <h2 className="font-bold text-gray-900">Team Community</h2>
        <p className="text-xs text-gray-400">Share updates, ask questions, celebrate wins</p>
      </div>

      {/* Posts */}
      <div className="flex-1 overflow-y-auto space-y-3 pr-1">
        {posts.length === 0 && (
          <p className="text-sm text-gray-400 text-center py-12">No posts yet — be the first to share!</p>
        )}
        {posts.map(post => {
          const p = (post as any).profiles
          const isMyPost = post.user_id === profile.id
          const canDelete = isMyPost || isAdmin

          return (
            <div key={post.id} className="card p-4">
              <div className="flex items-start gap-3">
                <div
                  className="w-9 h-9 rounded-full flex items-center justify-center text-white text-sm font-bold flex-shrink-0"
                  style={{ backgroundColor: p?.color_groups?.hex_color ?? '#4f46e5' }}
                >
                  {p?.full_name?.slice(0, 1) ?? '?'}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-0.5">
                    <span className="font-semibold text-sm text-gray-900">{p?.full_name ?? 'Unknown'}</span>
                    <span className="text-xs text-gray-400">{p?.member_id}</span>
                    <span className="text-xs bg-gray-100 text-gray-500 px-1.5 py-0.5 rounded">
                      {getStatusLabel(p?.status)}
                    </span>
                    {p?.color_groups && (
                      <div className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: p.color_groups.hex_color }} title={p.color_groups.name} />
                    )}
                  </div>
                  <p className="text-sm text-gray-700 whitespace-pre-wrap break-words">{post.content}</p>
                  <div className="text-xs text-gray-400 mt-1">
                    {format(parseISO(post.created_at), 'MMM d, h:mm a')}
                  </div>
                </div>
                {canDelete && (
                  <button
                    onClick={() => deletePost(post.id)}
                    className="p-1.5 rounded-lg text-gray-300 hover:text-red-500 hover:bg-red-50 transition-colors flex-shrink-0"
                  >
                    <Trash2 size={14} />
                  </button>
                )}
              </div>
            </div>
          )
        })}
        <div ref={bottomRef} />
      </div>

      {/* Compose */}
      <div className="card p-4 mt-4 flex-shrink-0">
        {msg && <p className="text-sm text-red-600 mb-2">{msg}</p>}
        <div className="flex gap-3 items-end">
          <div
            className="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-bold flex-shrink-0"
            style={{ backgroundColor: profile.color_groups?.hex_color ?? '#4f46e5' }}
          >
            {profile.full_name.slice(0, 1)}
          </div>
          <div className="flex-1">
            <textarea
              className="input resize-none"
              rows={3}
              placeholder="Share an update, ask a question, or celebrate a win…"
              value={content}
              onChange={e => setContent(e.target.value)}
              onKeyDown={e => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault()
                  post()
                }
              }}
            />
          </div>
          <button
            onClick={post}
            disabled={posting || !content.trim()}
            className="btn-primary p-3 flex-shrink-0"
          >
            <Send size={16} />
          </button>
        </div>
        <p className="text-xs text-gray-400 mt-1.5">Press Enter to post · Shift+Enter for new line</p>
      </div>
    </div>
  )
}
