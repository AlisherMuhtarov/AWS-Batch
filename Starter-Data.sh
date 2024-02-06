# Used to randomly generate customer data

for i in {1..30}; do
    echo "Customer ID: $i" > Customer-Data/file$i.txt
    echo "Customer Name: Customer$i" >> Customer-Data/file$i.txt
    echo "Customer Spend Amount: $((RANDOM % 1000 + 1))" >> Customer-Data/file$i.txt
done
