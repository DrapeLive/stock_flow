import { Document, Page, Text, View, StyleSheet } from "@react-pdf/renderer";
import { InvoiceResponse } from "@/types/order";
import { IndianRupee } from "lucide-react";

// Styles
const styles = StyleSheet.create({
  page: {
    padding: 30,
    fontSize: 12,
    fontFamily: "Helvetica",
  },
  section: {
    marginBottom: 10,
  },
  header: {
    fontSize: 20,
    marginBottom: 10,
    fontWeight: "bold",
  },
  subText: {
    fontSize: 10,
    color: "gray",
  },
  table: {
    marginTop: 10,
    borderWidth: 1,
    borderColor: "#eee",
  },
  row: {
    flexDirection: "row",
    borderBottomWidth: 1,
    borderColor: "#eee",
    padding: 6,
  },
  col1: { width: "25%" },
  col2: { width: "15%", textAlign: "center" },
  col3: { width: "20%", textAlign: "center" },
  col4: { width: "20%", textAlign: "center" },
  col5: { width: "20%", textAlign: "right" },
  bold: { fontWeight: "bold" },
  total: {
    marginTop: 15,
    textAlign: "right",
    fontSize: 14,
    fontWeight: "bold",
  },
});

// Helpers
const formatDate = (iso: string) => new Date(iso).toLocaleDateString("en-IN");

const formatTime = (iso: string) => new Date(iso).toLocaleTimeString("en-IN");

// Component
export const InvoicePDF = ({ invoice }: { invoice: InvoiceResponse }) => (
  <Document>
    <Page size="A4" style={styles.page}>
      {/* Header */}
      <Text style={styles.header}>
        Invoice #{invoice.id.toString().padStart(4, "0")}
      </Text>

      <View style={styles.section}>
        <Text>Date: {formatDate(invoice.created_at)}</Text>
        <Text>Time: {formatTime(invoice.created_at)}</Text>
      </View>

      {/* Customer */}
      <View style={styles.section}>
        <Text style={styles.bold}>Customer:</Text>
        <Text>{invoice.customer.name}</Text>
        <Text>{invoice.customer.contact}</Text>
      </View>

      {/* Agent */}
      <View style={styles.section}>
        <Text style={styles.bold}>Agent:</Text>
        <Text>{invoice.agent.username}</Text>
        <Text>{invoice.agent.contact}</Text>
      </View>

      {/* Items Table */}
      <View style={styles.table}>
        {/* Header Row */}
        <View style={[styles.row, styles.bold]}>
          <Text style={styles.col1}>Item</Text>
          <Text style={styles.col2}>Size</Text>
          <Text style={styles.col3}>Price</Text>
          <Text style={styles.col4}>Qty</Text>
          <Text style={styles.col5}>Amount</Text>
        </View>

        {/* Data Rows */}
        {invoice.items.map((item) => (
          <View key={item.id} style={styles.row}>
            <Text style={styles.col1}>{item.item_name}</Text>
            <Text style={styles.col2}>{item.size_group}</Text>
            <Text style={styles.col3}>{item.item_price}</Text>
            <Text style={styles.col4}>{item.quantity}</Text>
            <Text style={styles.col5}>
              <IndianRupee /> {parseFloat(String(item.item_price)) * item.quantity}
            </Text>
          </View>
        ))}
      </View>

      {/* Total */}
      <Text style={styles.total}>
        Total: <IndianRupee /> {invoice.total_price}
      </Text>
    </Page>
  </Document>
);
