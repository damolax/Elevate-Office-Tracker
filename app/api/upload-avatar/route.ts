import { NextResponse } from 'next/server'
import { createAdminClient, createClient } from '@/lib/supabase/server'

const MAX_AVATAR_BYTES = 5 * 1024 * 1024

export async function POST(request: Request) {
  try {
    const formData = await request.formData()
    const file = formData.get('file') as File | null
    const userId = formData.get('userId') as string | null

    if (!file || !userId) {
      return NextResponse.json({ error: 'File and userId required' }, { status: 400 })
    }

    const sessionClient = createClient()
    const { data: { user: requester } } = await sessionClient.auth.getUser()
    if (!requester) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Profile pictures are self-service. Never trust a userId supplied by the
    // browser to authorize writing into another member's storage/profile row.
    if (requester.id !== userId) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    if (!file.type.startsWith('image/')) {
      return NextResponse.json({ error: 'Only image files are allowed' }, { status: 400 })
    }
    if (file.size > MAX_AVATAR_BYTES) {
      return NextResponse.json({ error: 'Image must be 5 MB or smaller' }, { status: 400 })
    }

    const ext = file.name.split('.').pop()?.toLowerCase().replace(/[^a-z0-9]/g, '') || 'jpg'
    const path = `${requester.id}/avatar.${ext}`
    const bytes = await file.arrayBuffer()
    const admin = createAdminClient()

    const { error: uploadError } = await admin.storage
      .from('avatars')
      .upload(path, bytes, {
        contentType: file.type,
        upsert: true,
      })

    if (uploadError) {
      return NextResponse.json({ error: uploadError.message }, { status: 400 })
    }

    const { data: { publicUrl } } = admin.storage
      .from('avatars')
      .getPublicUrl(path)

    const urlWithCacheBust = `${publicUrl}?t=${Date.now()}`

    const { error: updateError } = await admin
      .from('profiles')
      .update({ profile_picture: urlWithCacheBust })
      .eq('id', requester.id)

    if (updateError) {
      return NextResponse.json({ error: updateError.message }, { status: 400 })
    }

    return NextResponse.json({ ok: true, url: urlWithCacheBust })
  } catch (err: unknown) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Unknown error' },
      { status: 500 }
    )
  }
}
