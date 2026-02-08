package auditor

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	asset "cloud.google.com/go/asset/apiv1"
	"cloud.google.com/go/asset/apiv1/assetpb"
	"cloud.google.com/go/bigquery"
	config "cloud.google.com/go/config/apiv1"
	"cloud.google.com/go/config/apiv1/configpb"
	"cloud.google.com/go/pubsub"
	"google.golang.org/api/iterator"
)

type ResourceRow struct {
	ResourceName  string    `bigquery:"resource_name"`
	AssetType     string    `bigquery:"asset_type"`
	DiscoveryTime time.Time `bigquery:"discovery_time"`
}

func AuditResources(ctx context.Context, m interface{}) error {
	projectID := os.Getenv("GCP_PROJECT")
	location := "us-central1"
	topicID := "resource-audit-topic"

	// Client Setup
	assetClient, err := asset.NewClient(ctx)
	if err != nil {
		return fmt.Errorf("failed asset client: %w", err)
	}
	defer assetClient.Close()

	imClient, err := config.NewClient(ctx)
	if err != nil {
		return fmt.Errorf("failed im client: %w", err)
	}
	defer imClient.Close()

	bqClient, err := bigquery.NewClient(ctx, projectID)
	if err != nil {
		return fmt.Errorf("failed bq client: %w", err)
	}
	defer bqClient.Close()

	pubClient, err := pubsub.NewClient(ctx, projectID)
	if err != nil {
		return fmt.Errorf("failed pubsub client: %w", err)
	}
	defer pubClient.Close()

	// Get Assets from Resource Manager
	realityMap := make(map[string]string)
	itAsset := assetClient.SearchAllResources(ctx, &assetpb.SearchAllResourcesRequest{
		Scope: fmt.Sprintf("projects/%s", projectID),
	})
	for {
		res, err := itAsset.Next()
		if err == iterator.Done {
			break
		}
		if err != nil || res == nil {
			continue
		}
		realityMap[res.Name] = res.AssetType
	}

	// Get Assets from Infrastructure Manager
	managedSet := make(map[string]bool)
	itDep := imClient.ListDeployments(ctx, &configpb.ListDeploymentsRequest{
		Parent: fmt.Sprintf("projects/%s/locations/%s", projectID, location),
	})

	for {
		dep, err := itDep.Next()
		if err == iterator.Done {
			break
		}
		if err != nil || dep == nil {
			break
		} // Panic prevention

		// Safely fetch resources for the latest revision
		itRes := imClient.ListResources(ctx, &configpb.ListResourcesRequest{
			Parent: fmt.Sprintf("%s/revisions/latest", dep.Name),
		})
		if itRes == nil {
			continue
		}

		for {
			res, err := itRes.Next()
			if err == iterator.Done {
				break
			}
			if err != nil || res == nil {
				break
			}

			if res.CaiAssets != nil {
				for caiName := range res.CaiAssets {
					managedSet[caiName] = true
				}
			}
		}
	}

	// Compare and find unmanaged resources
	var rows []*ResourceRow
	var flaggedNames []string
	ignore := []string{"/networks/default", "serviceAccount:service-"}

	for name, assetType := range realityMap {
		if !managedSet[name] {
			isIgnored := false
			for _, p := range ignore {
				if strings.Contains(name, p) {
					isIgnored = true
					break
				}
			}
			if !isIgnored {
				rows = append(rows, &ResourceRow{ResourceName: name, AssetType: assetType, DiscoveryTime: time.Now()})
				flaggedNames = append(flaggedNames, name)
			}
		}
	}

	// Output to BQ and PubSub
	if len(rows) > 0 {
		// Truncate table first
		q := bqClient.Query("DELETE FROM `managed_governance.unmanaged_resources` WHERE true")
		if _, err := q.Run(ctx); err != nil {
			log.Printf("BQ delete error: %v", err)
		}

		// Insert fresh findings
		inserter := bqClient.Dataset("managed_governance").Table("unmanaged_resources").Inserter()
		if err := inserter.Put(ctx, rows); err != nil {
			log.Printf("BQ insert error: %v", err)
		}

		// Send Alerts to PubSub
		data, _ := json.Marshal(flaggedNames)
		pubClient.Topic(topicID).Publish(ctx, &pubsub.Message{Data: data})

		log.Printf("Audit Finished: Found %d unmanaged resources.", len(rows))
	} else {
		log.Println("Audit Finished: 0 unmanaged resources found.")
	}

	return nil
}
