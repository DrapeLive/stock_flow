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
  display_order?: string | number;
}
interface Item {
  name: string;
  price: string | number;
  category?: string;
  fabric?: string;
  variants: Variant[];
}
interface QRLabelPdfProps {
  item: Item;
  qrImages: Record<number, string>;
  id?: string;
}

const styles = StyleSheet.create({
  page: {
    padding: 4,
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    gap: 2,
    backgroundColor: "#fff",
  },
  name: {
    fontFamily: "Helvetica",
    fontSize: 11,
    fontWeight: 800,
    lineHeight: 1.05,
    textAlign: "center",
    maxLines: 2,
    textOverflow: "ellipsis",
  },
  details: {
    fontFamily: "Helvetica",
    fontSize: 6.5,
    lineHeight: 1.05,
    textAlign: "center",
    maxLines: 2,
  },
  variant: {
    fontFamily: "Helvetica",
    fontSize: 10,
    lineHeight: 1.05,
    padding: 1.5,
    fontWeight: 600,
  },
  price: {
    fontFamily: "Helvetica",
    fontSize: 10,
    fontWeight: 800,
    lineHeight: 1.05,
  },
  qr: {
    width: 60,
    height: 60,
  },
});

export const QRLabelPdf = ({ item, qrImages, id }: QRLabelPdfProps) => (
  <Document>
    {item.variants.map((variant, index) => {
      return (
        <Page key={variant.id} size={[70.87, 141.73]} style={styles.page}>
          <Text style={styles.name}>{item.name}</Text>
          {(item.category || item.fabric) ? (
            <Text style={styles.details}>{[item.category, item.fabric].filter(Boolean).join("\n")}</Text>
          ) : null}
          {variant.display_order ? (
            <Text style={styles.variant}>Color #{variant.display_order}</Text>
          ) : null}
          <View>
            {/* eslint-disable-next-line*/}
            <Image src={qrImages[variant.id]} style={styles.qr} />
          </View>
          <Text style={styles.price}>Rs. {Number(item.price).toFixed(2)}</Text>
        </Page>
      );
    })}
  </Document>
);
