'use client'

import { useEffect, useRef, useState } from 'react'
import QRCode from 'qrcode'
import type { Profile } from '@/lib/types'

export default function QRCodeDisplay({ profile }: { profile: Profile }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [appUrl, setAppUrl] = useState('')

  useEffect(() => {
    const base = process.env.NEXT_PUBLIC_APP_URL ?? window.location.origin
    const url = `${base}/attendance/scan`
    setAppUrl(url)
    if (canvasRef.current) {
      QRCode.toCanvas(canvasRef.current, url, {
        width: 280,
        margin: 2,
        color: { dark: '#1e1b4b', light: '#ffffff' },
      })
    }
  }, [])

  function downloadQR() {
    const canvas = canvasRef.current
    if (!canvas) return
    const link = document.createElement('a')
    link.download = 'elevate-attendance-qr.png'
    link.href = canvas.toDataURL()
    link.click()
  }

  return (
    <div className="card p-6 max-w-sm mx-auto text-center">
      <h2 className="section-title mb-1">Office QR Code</h2>
      <p className="text-sm text-gray-500 mb-6">
        Display this code at the office for members to scan and sign in/out.
      </p>
      <div className="inline-block p-4 bg-white rounded-xl shadow-sm border border-gray-100">
        <canvas ref={canvasRef} className="block" />
      </div>
      <p className="text-xs text-gray-400 mt-3 break-all">{appUrl}</p>
      <button onClick={downloadQR} className="btn-secondary mt-4 mx-auto">
        Download QR Code
      </button>
    </div>
  )
}
