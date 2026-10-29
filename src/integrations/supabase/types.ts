export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      admin_notes: {
        Row: {
          author_id: string
          booking_request_id: string | null
          car_proposal_id: string | null
          created_at: string
          id: string
          note: string
        }
        Insert: {
          author_id: string
          booking_request_id?: string | null
          car_proposal_id?: string | null
          created_at?: string
          id?: string
          note: string
        }
        Update: {
          author_id?: string
          booking_request_id?: string | null
          car_proposal_id?: string | null
          created_at?: string
          id?: string
          note?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_notes_booking_request_id_fkey"
            columns: ["booking_request_id"]
            isOneToOne: false
            referencedRelation: "booking_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_notes_car_proposal_id_fkey"
            columns: ["car_proposal_id"]
            isOneToOne: false
            referencedRelation: "car_proposals"
            referencedColumns: ["id"]
          },
        ]
      }
      booking_requests: {
        Row: {
          car_id: string | null
          car_name: string
          city: string
          created_at: string
          email: string
          first_name: string
          id: string
          last_name: string
          message: string
          phone: string
          service_type: string
          status: Database["public"]["Enums"]["booking_status"]
          updated_at: string
          venue: string
          wedding_date: string
          wedding_time: string
        }
        Insert: {
          car_id?: string | null
          car_name: string
          city: string
          created_at?: string
          email: string
          first_name: string
          id?: string
          last_name: string
          message?: string
          phone: string
          service_type: string
          status?: Database["public"]["Enums"]["booking_status"]
          updated_at?: string
          venue: string
          wedding_date: string
          wedding_time: string
        }
        Update: {
          car_id?: string | null
          car_name?: string
          city?: string
          created_at?: string
          email?: string
          first_name?: string
          id?: string
          last_name?: string
          message?: string
          phone?: string
          service_type?: string
          status?: Database["public"]["Enums"]["booking_status"]
          updated_at?: string
          venue?: string
          wedding_date?: string
          wedding_time?: string
        }
        Relationships: [
          {
            foreignKeyName: "booking_requests_car_id_fkey"
            columns: ["car_id"]
            isOneToOne: false
            referencedRelation: "cars"
            referencedColumns: ["id"]
          },
        ]
      }
      car_images: {
        Row: {
          alt_text: string
          car_id: string
          created_at: string
          id: string
          is_cover: boolean
          sort_order: number
          storage_path: string
        }
        Insert: {
          alt_text?: string
          car_id: string
          created_at?: string
          id?: string
          is_cover?: boolean
          sort_order?: number
          storage_path: string
        }
        Update: {
          alt_text?: string
          car_id?: string
          created_at?: string
          id?: string
          is_cover?: boolean
          sort_order?: number
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "car_images_car_id_fkey"
            columns: ["car_id"]
            isOneToOne: false
            referencedRelation: "cars"
            referencedColumns: ["id"]
          },
        ]
      }
      car_proposals: {
        Row: {
          availability: string
          brand: string
          city: string
          color: string
          created_at: string
          description: string
          desired_rate: number
          email: string
          first_name: string
          id: string
          last_name: string
          message: string
          model: string
          phone: string
          schedules: string
          status: Database["public"]["Enums"]["proposal_status"]
          travel_zone: string
          updated_at: string
          vehicle_type: string
          year: number
        }
        Insert: {
          availability: string
          brand: string
          city: string
          color: string
          created_at?: string
          description: string
          desired_rate: number
          email: string
          first_name: string
          id?: string
          last_name: string
          message?: string
          model: string
          phone: string
          schedules: string
          status?: Database["public"]["Enums"]["proposal_status"]
          travel_zone: string
          updated_at?: string
          vehicle_type: string
          year: number
        }
        Update: {
          availability?: string
          brand?: string
          city?: string
          color?: string
          created_at?: string
          description?: string
          desired_rate?: number
          email?: string
          first_name?: string
          id?: string
          last_name?: string
          message?: string
          model?: string
          phone?: string
          schedules?: string
          status?: Database["public"]["Enums"]["proposal_status"]
          travel_zone?: string
          updated_at?: string
          vehicle_type?: string
          year?: number
        }
        Relationships: []
      }
      car_videos: {
        Row: {
          car_id: string
          created_at: string
          id: string
          sort_order: number
          storage_path: string
          title: string
        }
        Insert: {
          car_id: string
          created_at?: string
          id?: string
          sort_order?: number
          storage_path: string
          title?: string
        }
        Update: {
          car_id?: string
          created_at?: string
          id?: string
          sort_order?: number
          storage_path?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "car_videos_car_id_fkey"
            columns: ["car_id"]
            isOneToOne: false
            referencedRelation: "cars"
            referencedColumns: ["id"]
          },
        ]
      }
      cars: {
        Row: {
          active: boolean
          availability: string
          brand: string
          category: string
          color: string | null
          created_at: string
          description: string
          featured: boolean
          features: Json
          id: string
          model: string
          name: string
          price_from: number | null
          service_information: Json
          short_description: string
          slug: string
          sort_order: number
          updated_at: string
          year: number | null
        }
        Insert: {
          active?: boolean
          availability?: string
          brand: string
          category: string
          color?: string | null
          created_at?: string
          description?: string
          featured?: boolean
          features?: Json
          id?: string
          model: string
          name: string
          price_from?: number | null
          service_information?: Json
          short_description?: string
          slug: string
          sort_order?: number
          updated_at?: string
          year?: number | null
        }
        Update: {
          active?: boolean
          availability?: string
          brand?: string
          category?: string
          color?: string | null
          created_at?: string
          description?: string
          featured?: boolean
          features?: Json
          id?: string
          model?: string
          name?: string
          price_from?: number | null
          service_information?: Json
          short_description?: string
          slug?: string
          sort_order?: number
          updated_at?: string
          year?: number | null
        }
        Relationships: []
      }
      gallery: {
        Row: {
          active: boolean
          created_at: string
          description: string
          event_date: string | null
          id: string
          media_type: string
          service_type: string | null
          sort_order: number
          storage_path: string
          title: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          description?: string
          event_date?: string | null
          id?: string
          media_type: string
          service_type?: string | null
          sort_order?: number
          storage_path: string
          title: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          description?: string
          event_date?: string | null
          id?: string
          media_type?: string
          service_type?: string | null
          sort_order?: number
          storage_path?: string
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          first_name: string
          id: string
          last_name: string
          phone: string | null
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          first_name?: string
          id: string
          last_name?: string
          phone?: string | null
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          first_name?: string
          id?: string
          last_name?: string
          phone?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      proposal_images: {
        Row: {
          created_at: string
          id: string
          proposal_id: string
          storage_path: string
        }
        Insert: {
          created_at?: string
          id?: string
          proposal_id: string
          storage_path: string
        }
        Update: {
          created_at?: string
          id?: string
          proposal_id?: string
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "proposal_images_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "car_proposals"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
    }
    Enums: {
      app_role: "admin" | "editor"
      booking_status:
        | "new"
        | "contacted"
        | "pending"
        | "confirmed"
        | "cancelled"
      proposal_status: "new" | "reviewing" | "accepted" | "rejected"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["admin", "editor"],
      booking_status: ["new", "contacted", "pending", "confirmed", "cancelled"],
      proposal_status: ["new", "reviewing", "accepted", "rejected"],
    },
  },
} as const
