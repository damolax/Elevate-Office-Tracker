'use client'

import { createContext, useContext, useState, ReactNode } from 'react'

interface ProfileContextType {
  profilePicture: string | null
  setProfilePicture: (url: string | null) => void
}

const ProfileContext = createContext<ProfileContextType>({
  profilePicture: null,
  setProfilePicture: () => {},
})

export function ProfileProvider({ children, initialPicture }: { children: ReactNode; initialPicture: string | null }) {
  const [profilePicture, setProfilePicture] = useState(initialPicture)
  return (
    <ProfileContext.Provider value={{ profilePicture, setProfilePicture }}>
      {children}
    </ProfileContext.Provider>
  )
}

export function useProfilePicture() {
  return useContext(ProfileContext)
}
