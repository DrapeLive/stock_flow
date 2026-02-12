import { OrderItems } from "@/types/order";
import Image from "next/image";

type Props = {
  items: OrderItems | undefined;
};

const OrderItem: React.FC<Props> = ({ items }) => {
  return (
    <div className="pt-3 space-y-3">
      {items?.map((item, index) => (
        <div
          className="flex w-full border-b border-(--color-border) py-2"
          key={index}
        >
          <div className="flex justify-between">
            <Image src={item.variant.image} width={35} height={35} alt="" />
            <div className="pl-4 min-w-40">
              <h6>{item.item.name}</h6>
              <p>{item.variant.color}</p>
            </div>
          </div>
          <div className="ml-6 flex justify-around w-full">
            <div className="flex items-center ">
              <h6>{item.size.size}</h6>
            </div>
            <div className="flex flex-col justify-center items-center">
              <h3>{item.quantity}</h3>
              <p>Pieces</p>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};

export default OrderItem;
