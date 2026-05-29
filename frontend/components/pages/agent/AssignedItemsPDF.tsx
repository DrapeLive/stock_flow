import {
    Document,
    Page,
    View,
    Text,
    Image,
    StyleSheet,
} from "@react-pdf/renderer";

export interface PDFVariant {
    variantId: number;
    itemName: string;
    itemType?: string;
    itemPrice: string;
    imageDataUrl: string | null;
    qrCode: string | null;
    sizes: { size: string; stock: number }[];
}

interface AssignedItemsPDFProps {
    variants: PDFVariant[];
    agentName: string;
    tabLabel: string;
    generatedAt: string;
}

const styles = StyleSheet.create({
    page: {
        padding: 40,
        fontSize: 10,
        fontFamily: "Helvetica",
        color: "#1a1a1a",
    },
    header: {
        marginBottom: 24,
        borderBottomWidth: 2,
        borderBottomColor: "#000",
        paddingBottom: 12,
    },
    title: {
        fontSize: 18,
        fontWeight: "bold",
        marginBottom: 4,
    },
    subtitle: {
        fontSize: 10,
        color: "#666",
        marginBottom: 2,
    },
    table: {
        marginTop: 8,
    },
    tableHeader: {
        flexDirection: "row",
        borderBottomWidth: 1,
        borderBottomColor: "#ccc",
        paddingVertical: 6,
        fontWeight: "bold",
        fontSize: 9,
        color: "#444",
        textTransform: "uppercase",
    },
    tableRow: {
        flexDirection: "row",
        borderBottomWidth: 1,
        borderBottomColor: "#eee",
        paddingVertical: 6,
        alignItems: "center",
    },
    imageCell: {
        width: 40,
        paddingRight: 8,
    },
    itemImage: {
        width: 32,
        height: 32,
        objectFit: "cover",
        borderRadius: 4,
    },
    nameCell: {
        flex: 1,
        paddingRight: 8,
    },
    nameText: {
        fontSize: 10,
        fontWeight: "bold",
    },
    typeCell: {
        width: 50,
        paddingRight: 8,
    },
    typeText: {
        fontSize: 9,
        color: "#666",
        textTransform: "capitalize",
    },
    priceCell: {
        width: 50,
        paddingRight: 8,
        textAlign: "right",
    },
    priceText: {
        fontSize: 10,
    },
    qrCell: {
        width: 70,
        paddingRight: 8,
    },
    qrText: {
        fontSize: 7,
        color: "#999",
        fontFamily: "Courier",
    },
    footer: {
        marginTop: 20,
        paddingTop: 12,
        borderTopWidth: 1,
        borderTopColor: "#ccc",
        fontSize: 10,
        fontWeight: "bold",
        textAlign: "right",
    },
    imagePlaceholder: {
        width: 32,
        height: 32,
        backgroundColor: "#f0f0f0",
        borderRadius: 4,
    },
});

export default function AssignedItemsPDF({
    variants,
    agentName,
    tabLabel,
    generatedAt,
}: AssignedItemsPDFProps) {
    return (
        <Document>
            <Page size="A4" style={styles.page}>
                <View style={styles.header}>
                    <Text style={styles.title}>Assigned Items Summary</Text>
                    <Text style={styles.subtitle}>Agent: {agentName}</Text>
                    <Text style={styles.subtitle}>{tabLabel}</Text>
                    <Text style={styles.subtitle}>
                        Generated: {generatedAt}
                    </Text>
                </View>

                <View style={styles.table}>
                    <View style={styles.tableHeader}>
                        <Text style={styles.imageCell}></Text>
                        <Text style={styles.nameCell}>Item</Text>
                        <Text style={styles.typeCell}>Type</Text>
                        <Text style={styles.priceCell}>Price</Text>
                        <Text style={styles.qrCell}>QR Code</Text>
                    </View>

                    {variants.map((v, i) => (
                        <View style={styles.tableRow} key={v.variantId ?? i}>
                            <View style={styles.imageCell}>
                                {v.imageDataUrl ? (
                                    <Image
                                        src={v.imageDataUrl}
                                        style={styles.itemImage}
                                    />
                                ) : (
                                    <View style={styles.imagePlaceholder} />
                                )}
                            </View>
                            <View style={styles.nameCell}>
                                <Text style={styles.nameText}>
                                    {v.itemName}
                                </Text>
                                {v.sizes.length > 0 && (
                                    <Text style={{ fontSize: 8, color: "#999", marginTop: 2 }}>
                                        {v.sizes.map((s) => `${s.size}:${s.stock}`).join(", ")}
                                    </Text>
                                )}
                            </View>
                            <View style={styles.typeCell}>
                                <Text style={styles.typeText}>
                                    {v.itemType || "—"}
                                </Text>
                            </View>
                            <View style={styles.priceCell}>
                                <Text style={styles.priceText}>
                                    Rs. {v.itemPrice}
                                </Text>
                            </View>
                            <View style={styles.qrCell}>
                                <Text style={styles.qrText}>
                                    {v.qrCode
                                        ? v.qrCode.length > 16
                                            ? v.qrCode.slice(0, 16) + "…"
                                            : v.qrCode
                                        : "—"}
                                </Text>
                            </View>
                        </View>
                    ))}
                </View>

                <View style={styles.footer}>
                    <Text>Total variants: {variants.length}</Text>
                </View>
            </Page>
        </Document>
    );
}
