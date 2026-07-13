import { isOnline, lastSeenLabel } from '@/lib/useLastSeen'
'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Profile, CommunityPost } from '@/lib/types'
import { getStatusLabel } from '@/lib/utils'
import { Send, Trash2 } from 'lucide-react'
import { format, parseISO } from 'date-fns'

export default function CommunityClient({
  profile, initialPosts, isAdmin,
}: {
  profile: Profile
  initialPosts: CommunityPost[]
  isAdmin: boolean
}) {
  const [posts, setPosts] = useState<CommunityPost[]>(initialPosts)
  const [content, setContent] = useState('')
  const [posting, setPosting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [connected, setConnected] = useState(false)
  const bottomRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  const scrollToBottom = useCallback((smooth = true) => {
    bottomRef.current?.scrollIntoView({ behavior: smooth ? 'smooth' : 'auto' })
  }, [])

  useEffect(() => {
    // Scroll to bottom on initial load
    scrollToBottom(false)
  }, [])

  useEffect(() => {
    const supabase = createClient()

    const channel = supabase
      .channel('community-realtime')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'community_posts',
      }, async (payload) => {
        // Skip if this is our own post — we already added it optimistically
        if (payload.new.user_id === profile.id) return

        // Fetch the full post with profile data
        const { data } = await supabase
          .from('community_posts')
          .select('*, profiles(id, full_name, member_id, profile_picture, status, last_seen, color_groups!profiles_color_group_id_fkey(name, hex_color))')
          .eq('id', payload.new.id)
          .single()

        if (data) {
          setPosts(prev => {
            // Avoid duplicates
            if (prev.find(p => p.id === data.id)) return prev
            return [data as CommunityPost, ...prev]
          })
          setTimeout(() => scrollToBottom(), 100)
        }
      })
      .on('postgres_changes', {
        event: 'DELETE',
        schema: 'public',
        table: 'community_posts',
      }, (payload) => {
        setPosts(prev => prev.filter(p => p.id !== payload.old.id))
      })
      .subscribe((status) => {
        setConnected(status === 'SUBSCRIBED')
      })

    return () => { supabase.removeChannel(channel) }
  }, [profile.id, scrollToBottom])

  async function post() {
    if (!content.trim() || posting) return
    const text = content.trim()
    setContent('')
    setPosting(true)
    setError(null)

    // Optimistic update — add post immediately to UI
    const tempId = `temp-${Date.now()}`
    const optimisticPost: CommunityPost = {
      id: tempId,
      user_id: profile.id,
      content: text,
      attachment_url: null,
      attachment_type: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      profiles: {
        id: profile.id,
        full_name: profile.full_name,
        member_id: profile.member_id,
        profile_picture: profile.profile_picture,
        status: profile.status,
      } as any,
    }
    setPosts(prev => [optimisticPost, ...prev])
    setTimeout(() => scrollToBottom(), 100)

    const supabase = createClient()
    const { data, error: insertError } = await supabase
      .from('community_posts')
      .insert({ user_id: profile.id, content: text })
      .select('*, profiles(id, full_name, member_id, profile_picture, status, color_groups!profiles_color_group_id_fkey(name, hex_color))')
      .single()

    if (insertError) {
      // Remove optimistic post on error
      setPosts(prev => prev.filter(p => p.id !== tempId))
      setContent(text)
      setError(insertError.message)
    } else if (data) {
      // Replace optimistic post with real data
      setPosts(prev => prev.map(p => p.id === tempId ? data as CommunityPost : p))
      supabase.from('activity_events').insert({
        type: 'community_post', actor_id: profile.id,
        message: `${profile.full_name} posted in Community`,
      })
    }

    setPosting(false)
    textareaRef.current?.focus()
  }

  async function deletePost(id: string) {
    // Optimistic remove
    setPosts(prev => prev.filter(p => p.id !== id))
    const supabase = createClient()
    const { error: delError } = await supabase.from('community_posts').delete().eq('id', id)
    if (delError) {
      // Restore post list on error
      setError(delError.message)
      window.location.reload()
    }
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      post()
    }
  }

  return (
    <div className="flex flex-col h-[calc(100vh-120px)] max-w-3xl mx-auto">
      {/* Header */}
      <div className="card p-4 mb-4 flex-shrink-0 flex items-center justify-between">
        <div>
          <h2 className="font-bold text-gray-900">Team Community</h2>
          <p className="text-xs text-gray-400">Share updates, ask questions, celebrate wins</p>
        </div>
        <div className={`flex items-center gap-1.5 text-xs font-medium ${connected ? 'text-green-600' : 'text-gray-400'}`}>
          <div className={`w-2 h-2 rounded-full ${connected ? 'bg-green-500' : 'bg-gray-300'}`} />
          {connected ? 'Live' : 'Connecting…'}
        </div>
      </div>

      {/* Posts feed */}
      <div className="flex-1 overflow-y-auto space-y-3 pr-1 flex flex-col-reverse">
        <div ref={bottomRef} />
        {posts.length === 0 && (
          <p className="text-sm text-gray-400 text-center py-12">No posts yet — be the first to share!</p>
        )}
        {posts.map(postItem => {
          const p = (postItem as any).profiles
          const isMyPost = postItem.user_id === profile.id
          const canDelete = isMyPost || isAdmin
          const isTemp = postItem.id.startsWith('temp-')

          return (
            <div key={postItem.id} className={`card p-4 transition-opacity ${isTemp ? 'opacity-70' : 'opacity-100'}`}>
              <div className="flex items-start gap-3">
                <div className="w-9 h-9 rounded-full flex-shrink-0 overflow-hidden">
                  {p?.profile_picture ? (
                    <img src={p.profile_picture} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-white text-sm font-bold"
                      style={{ backgroundColor: p?.color_groups?.hex_color ?? '#4f46e5' }}>
                      {p?.full_name?.slice(0, 1) ?? '?'}
                    </div>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1 flex-wrap">
                    <span className="font-semibold text-sm text-gray-900">{p?.full_name ?? 'Unknown'}</span>
                    {p?.member_id && <span className="text-xs text-gray-400">{p.member_id}</span>}
                    {p?.status && (
                      <span className="text-xs bg-gray-100 text-gray-500 px-1.5 py-0.5 rounded">
                        {getStatusLabel(p.status)}
                      </span>
                    )}
                    {p?.color_groups && (
                      <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: p.color_groups.hex_color }} />
                    )}
                    {isMyPost && <span className="text-xs text-brand-500 font-medium">You</span>}
                  </div>
                  <p className="text-sm text-gray-700 whitespace-pre-wrap break-words leading-relaxed">{postItem.content}</p>
                  <div className="text-xs text-gray-400 mt-1.5">
                    {isTemp ? 'Sending…' : format(parseISO(postItem.created_at), 'MMM d, h:mm a')}
                  </div>
                </div>
                {canDelete && !isTemp && (
                  <button onClick={() => deletePost(postItem.id)}
                    className="p-1.5 rounded-lg text-gray-300 hover:text-red-500 hover:bg-red-50 transition-colors flex-shrink-0">
                    <Trash2 size={14} />
                  </button>
                )}
              </div>
            </div>
          )
        })}
      </div>

      {/* Compose */}
      <div className="card p-4 mt-4 flex-shrink-0">
        {error && <p className="text-sm text-red-600 mb-2">{error}</p>}
        <div className="flex gap-3 items-end">
          <div className="w-8 h-8 rounded-full flex-shrink-0 overflow-hidden">
            {profile.profile_picture ? (
              <img src={profile.profile_picture} alt="" className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full flex items-center justify-center text-white text-sm font-bold"
                style={{ backgroundColor: profile.color_groups?.hex_color ?? '#4f46e5' }}>
                {profile.full_name.slice(0, 1)}
              </div>
            )}
          </div>
          <div className="flex-1">
            <textarea
              ref={textareaRef}
              className="input resize-none"
              rows={3}
              placeholder="Share an update, ask a question, or celebrate a win…"
              value={content}
              onChange={e => setContent(e.target.value)}
              onKeyDown={handleKeyDown}
            />
          </div>
          <button onClick={post} disabled={posting || !content.trim()} className="btn-primary p-3 flex-shrink-0">
            <Send size={16} />
          </button>
        </div>
        <p className="text-xs text-gray-400 mt-1.5">Press Enter to post · Shift+Enter for new line</p>
      </div>
    </div>
  )
}
