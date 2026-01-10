
export interface User {
  id: number;
  name: string;
  email: string;
  role: 'admin' | 'editor' | 'user';
  status: 'active' | 'inactive';
  avatar?: string;
}

export interface Post {
  id: string;
  title: string;
  summary: string;
  views: number;
  authorId: number;
  publishedDate: string;
  tags: string[];
}

export const users: User[] = [
  {
    id: 1,
    name: "Alice Johnson",
    email: "alice@example.com",
    role: "admin",
    status: "active",
    avatar: "https://i.pravatar.cc/150?u=1",
  },
  {
    id: 2,
    name: "Bob Smith",
    email: "bob@example.com",
    role: "editor",
    status: "active",
    avatar: "https://i.pravatar.cc/150?u=2",
  },
  {
    id: 3,
    name: "Charlie Brown",
    email: "charlie@example.com",
    role: "user",
    status: "inactive",
  },
];


export const posts: Post[] = [
  {
    id: "post_01",
    title: "Understanding Next.js 16",
    summary: "A deep dive into the new features of Next.js 16 and React Server Components.",
    views: 1250,
    authorId: 1,
    publishedDate: "2024-01-15",
    tags: ["Next.js", "React", "Web Dev"],
  },
  {
    id: "post_02",
    title: "Mastering Tailwind CSS 4",
    summary: "How to configure the new CSS-first engine in Tailwind 4.",
    views: 980,
    authorId: 2,
    publishedDate: "2024-02-10",
    tags: ["CSS", "Tailwind", "Design"],
  },
  {
    id: "post_03",
    title: "TypeScript Best Practices",
    summary: "Why you should be using interfaces and strict mode.",
    views: 3400,
    authorId: 1,
    publishedDate: "2023-11-05",
    tags: ["TypeScript", "Coding"],
  },
];