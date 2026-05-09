"use client";

import {
  Document,
  Page,
  Text,
  View,
  StyleSheet,
  Image,
} from "@react-pdf/renderer";

interface Variant {
  id: number;
}

interface Item {
  name: string;
  price: string | number;
  variants: Variant[];
}

interface QRLabelPdfProps {
  item: Item;
  qrImages: Record<number, string>;
}

const styles = StyleSheet.create({
  page: {
    width: "58mm",
    height: "90mm",
    padding: 12,
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    backgroundColor: "#fff",
  },

  name: {
    fontSize: 11,
    fontWeight: 700,
    textAlign: "center",
  },

  variant: {
    fontSize: 9,
    padding: 4,
    backgroundColor: "#f0f0f0",
  },

  price: {
    fontSize: 14,
    fontWeight: 800,
  },

  qr: {
    width: 130,
    height: 130,
  },
});

export const QRLabelPdf = ({ item, qrImages }: QRLabelPdfProps) => (
  <Document>
    {item.variants.map((variant, index) => (
      <Page key={variant.id} size={[165, 255]} style={styles.page}>
        <Text style={styles.name}>{item.name}</Text>

        <Text style={styles.variant}>Variant #{index + 1}</Text>

        <View>
          {/* eslint-disable-next-line*/}
          <Image src={qrImages[variant.id]} style={styles.qr} />
        </View>

        <Text style={styles.price}>Rs. {Number(item.price).toFixed(2)}</Text>
      </Page>
    ))}
  </Document>
);
