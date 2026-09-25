import { describe, it, expect, vi } from 'vitest'
import { clearFormDataContentType } from '../../lib/api/axios'
import { itemToFormData } from '../../lib/form-utils'

const ImageLikeFile = (): File =>
  new File(['image-bytes'], 'red.png', { type: 'image/png' })

describe('clearFormDataContentType (media upload regression)', () => {
  it('deletes Content-Type for FormData payloads so the browser adds the multipart boundary', () => {
    const headers = { delete: vi.fn<(name: string) => void>() }
    const fd = itemToFormData({
      name: 'Shirt',
      description: '',
      price: '19.99',
      type: 'apparel',
      variants: [
        {
          image: ImageLikeFile(),
          display_order: '0',
          sizes: [{ size: 'M', stock: 5 }],
        },
      ],
    })

    clearFormDataContentType({ data: fd, headers })

    expect(headers.delete).toHaveBeenCalledWith('Content-Type')
  })

  it('leaves Content-Type untouched for plain JSON payloads', () => {
    const headers = { delete: vi.fn<(name: string) => void>() }

    clearFormDataContentType({ data: { name: 'Shirt' }, headers })

    expect(headers.delete).not.toHaveBeenCalled()
  })

  it('adds the variant image as a File object, never as a string or Promise', () => {
    const file = ImageLikeFile()
    const fd = itemToFormData({
      name: 'Shirt',
      description: '',
      price: '19.99',
      type: 'apparel',
      variants: [
        {
          image: file,
          display_order: '0',
          sizes: [{ size: 'M', stock: 5 }],
        },
      ],
    })

    const value = fd.get('variants[0]image')

    expect(value).toBe(file)
    expect(value).toBeInstanceOf(File)
    expect(typeof value).not.toBe('string')
    expect(value && typeof value === 'object' && 'type' in value).toBe(true)
  })
})